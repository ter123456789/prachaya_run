package com.example.prachaya_run

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var heartRate: HeartRateBridge? = null
    private var health: HealthBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        heartRate = HeartRateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        health = HealthBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Linking a watch account: the brand's sign-in page in the browser.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prachaya/browser")
            .setMethodCallHandler { call, result ->
                val url = call.argument<String>("url")
                if (call.method != "open" || url == null) return@setMethodCallHandler result.notImplemented()
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == HealthBridge.REQUEST_CODE) health?.onPermissionResult()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == HeartRateBridge.REQUEST_CODE) heartRate?.onPermissionsResult()
        if (requestCode == HealthBridge.REQUEST_CODE) health?.onPermissionResult()
    }
}
