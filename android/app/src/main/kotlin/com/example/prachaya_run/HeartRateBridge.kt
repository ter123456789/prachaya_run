package com.example.prachaya_run

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * `prachaya/heart_rate` (+ `/events`): a Bluetooth LE heart-rate sensor for
 * Dart's NativeHeartRateMonitor, which decodes the measurement bytes.
 *
 * GATT callbacks arrive on a binder thread; everything that touches the
 * channels or the state below is posted to the main thread. After an
 * unexpected drop it reconnects with autoConnect = true, which waits for
 * the sensor to come back in range. While recording, geolocator's
 * foreground service keeps the process (and this connection) alive.
 */
@SuppressLint("MissingPermission") // checked in hasPermissions() before use
class HeartRateBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    companion object {
        const val REQUEST_CODE = 0x4852 // "HR"
        private val HR_SERVICE: UUID = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        private val HR_MEASUREMENT: UUID = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        private val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val main = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? =
        (activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter
    private var sink: EventChannel.EventSink? = null
    private var pendingAccess: MethodChannel.Result? = null
    private var scanning = false
    private var gatt: BluetoothGatt? = null

    /** The sensor in use; null after `disconnect`. */
    private var sensorId: String? = null

    init {
        MethodChannel(messenger, "prachaya/heart_rate").setMethodCallHandler(::handle)
        EventChannel(messenger, "prachaya/heart_rate/events").setStreamHandler(this)
        // Bluetooth switched back on: pick the sensor up again.
        activity.registerReceiver(
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    if (state == BluetoothAdapter.STATE_ON && sensorId != null && gatt == null) {
                        connect(autoConnect = true)
                    }
                }
            },
            IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "access" -> access(result)
            "startScan" -> {
                startScan()
                result.success(null)
            }
            "stopScan" -> {
                stopScan()
                result.success(null)
            }
            "connect" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("bad_args", null, null)
                    return
                }
                drop()
                sensorId = id
                connect(autoConnect = false)
                result.success(null)
            }
            "disconnect" -> {
                drop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---- permissions -------------------------------------------------------

    private fun requiredPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Before Android 12, scanning needs location.
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasPermissions(): Boolean = requiredPermissions().all {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    private fun accessName(): String = when {
        adapter == null || !activity.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) -> "unsupported"
        !hasPermissions() -> "denied"
        !adapter.isEnabled -> "off"
        else -> "granted"
    }

    private fun access(result: MethodChannel.Result) {
        if (adapter == null || hasPermissions()) {
            result.success(accessName())
            return
        }
        pendingAccess?.success("denied")
        pendingAccess = result
        activity.requestPermissions(requiredPermissions(), REQUEST_CODE)
    }

    /** Forwarded from MainActivity.onRequestPermissionsResult. */
    fun onPermissionsResult() {
        pendingAccess?.success(accessName())
        pendingAccess = null
        if (sensorId != null && gatt == null) connect(autoConnect = true)
    }

    // ---- scanning ----------------------------------------------------------

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.scanRecord?.deviceName ?: result.device.name
            if (name.isNullOrEmpty()) return
            val hr = result.scanRecord?.serviceUuids?.contains(ParcelUuid(HR_SERVICE)) == true
            main.post {
                send(mapOf("event" to "found", "id" to result.device.address, "name" to name, "hr" to hr))
            }
        }
    }

    private fun startScan() {
        if (scanning || accessName() != "granted") return
        val scanner = adapter?.bluetoothLeScanner ?: return
        // No service filter: some wristbands only reveal 0x180D after connecting.
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner.startScan(null, settings, scanCallback)
        scanning = true
    }

    private fun stopScan() {
        if (!scanning) return
        scanning = false
        if (hasPermissions() && adapter?.isEnabled == true) {
            adapter.bluetoothLeScanner?.stopScan(scanCallback)
        }
    }

    // ---- connection --------------------------------------------------------

    private fun connect(autoConnect: Boolean) {
        val id = sensorId ?: return
        if (accessName() != "granted") {
            send(mapOf("event" to "link", "state" to "connecting"))
            return
        }
        val device: BluetoothDevice = try {
            adapter!!.getRemoteDevice(id)
        } catch (e: IllegalArgumentException) {
            send(mapOf("event" to "link", "state" to "disconnected"))
            return
        }
        send(mapOf("event" to "link", "state" to "connecting"))
        gatt = device.connectGatt(activity, autoConnect, callback, BluetoothDevice.TRANSPORT_LE)
    }

    /** Stops using the current sensor (user's choice, or another one picked). */
    private fun drop() {
        sensorId = null
        gatt?.let {
            if (hasPermissions()) {
                it.disconnect()
                it.close()
            }
        }
        gatt = null
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            main.post {
                if (g != gatt) return@post
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    g.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    // Out of range or switched off: wait for it to come back.
                    g.close()
                    gatt = null
                    connect(autoConnect = true)
                }
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            main.post {
                if (g != gatt) return@post
                val measurement = g.getService(HR_SERVICE)?.getCharacteristic(HR_MEASUREMENT)
                if (measurement == null) {
                    send(mapOf("event" to "link", "state" to "noHeartRate"))
                    return@post
                }
                g.setCharacteristicNotification(measurement, true)
                val cccd = measurement.getDescriptor(CCCD)
                if (cccd == null) {
                    send(mapOf("event" to "link", "state" to "connected"))
                    return@post
                }
                val enable = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    g.writeDescriptor(cccd, enable)
                } else {
                    @Suppress("DEPRECATION")
                    cccd.value = enable
                    @Suppress("DEPRECATION")
                    g.writeDescriptor(cccd)
                }
            }
        }

        override fun onDescriptorWrite(g: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            main.post {
                if (g != gatt || descriptor.uuid != CCCD) return@post
                val ok = status == BluetoothGatt.GATT_SUCCESS
                send(mapOf("event" to "link", "state" to if (ok) "connected" else "noHeartRate"))
            }
        }

        // Android 13+.
        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (characteristic.uuid != HR_MEASUREMENT) return
            val bytes = value.copyOf()
            main.post { if (g == gatt) send(mapOf("event" to "data", "bytes" to bytes)) }
        }

        // Android 12 and below.
        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(g: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return
            if (characteristic.uuid != HR_MEASUREMENT) return
            @Suppress("DEPRECATION")
            val bytes = characteristic.value?.copyOf() ?: return
            main.post { if (g == gatt) send(mapOf("event" to "data", "bytes" to bytes)) }
        }
    }

    private fun send(event: Map<String, Any>) {
        sink?.success(event)
    }
}
