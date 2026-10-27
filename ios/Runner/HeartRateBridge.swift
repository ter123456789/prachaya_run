import CoreBluetooth
import Flutter
import Foundation

/// `prachaya/heart_rate` (+ `/events`): a Bluetooth LE heart-rate sensor for
/// Dart's NativeHeartRateMonitor, which decodes the measurement bytes.
///
/// - The central manager is created on the first call, so the Bluetooth
///   permission prompt shows when the user first looks for a sensor.
/// - A pending `connect` never times out on iOS: after a drop it is issued
///   again and completes when the sensor comes back in range. With the
///   `bluetooth-central` background mode this keeps working with the
///   screen locked during a recording.
final class HeartRateBridge: NSObject, FlutterStreamHandler {
  private static let hrService = CBUUID(string: "180D")
  private static let hrMeasurement = CBUUID(string: "2A37")

  private let methods: FlutterMethodChannel
  private let events: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var central: CBCentralManager?
  private var pendingAccess: [FlutterResult] = []
  private var scanWanted = false
  private var seen: [UUID: CBPeripheral] = [:]
  /// The sensor in use; nil after `disconnect`.
  private var sensor: CBPeripheral?
  private var sensorId: UUID?

  init(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "prachaya/heart_rate", binaryMessenger: messenger)
    events = FlutterEventChannel(name: "prachaya/heart_rate/events", binaryMessenger: messenger)
    super.init()
    events.setStreamHandler(self)
    methods.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "access":
      let manager = ensureCentral()
      if manager.state == .unknown || manager.state == .resetting {
        pendingAccess.append(result)  // answered in centralManagerDidUpdateState
      } else {
        result(accessName(manager.state))
      }
    case "startScan":
      scanWanted = true
      seen.removeAll()
      startScanIfReady()
      result(nil)
    case "stopScan":
      scanWanted = false
      central?.stopScan()
      result(nil)
    case "connect":
      guard let args = call.arguments as? [String: Any], let raw = args["id"] as? String,
        let id = UUID(uuidString: raw)
      else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      drop()
      sensorId = id
      connectIfReady()
      result(nil)
    case "disconnect":
      drop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ensureCentral() -> CBCentralManager {
    if let central { return central }
    let manager = CBCentralManager(delegate: self, queue: .main)
    central = manager
    return manager
  }

  private func accessName(_ state: CBManagerState) -> String {
    switch state {
    case .poweredOn: return "granted"
    case .poweredOff: return "off"
    case .unsupported: return "unsupported"
    default: return "denied"
    }
  }

  private func startScanIfReady() {
    guard scanWanted else { return }
    let central = ensureCentral()
    guard central.state == .poweredOn else { return }
    // No service filter: some wristbands only reveal 0x180D after connecting.
    central.scanForPeripherals(withServices: nil, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: false
    ])
  }

  private func connectIfReady() {
    guard let id = sensorId else { return }
    let central = ensureCentral()
    guard central.state == .poweredOn else { return }
    let peripheral = sensor ?? seen[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first
    guard let peripheral else {
      send(["event": "link", "state": "disconnected"])
      return
    }
    sensor = peripheral
    peripheral.delegate = self
    send(["event": "link", "state": "connecting"])
    central.connect(peripheral, options: nil)
  }

  /// Stops using the current sensor (user's choice, or another one picked).
  private func drop() {
    let old = sensor
    sensor = nil
    sensorId = nil
    if let old { central?.cancelPeripheralConnection(old) }
  }

  private func send(_ event: [String: Any]) {
    sink?(event)
  }
}

extension HeartRateBridge: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let waiting = pendingAccess
    pendingAccess.removeAll()
    if central.state != .unknown && central.state != .resetting {
      waiting.forEach { $0(accessName(central.state)) }
    } else {
      pendingAccess = waiting
    }
    if central.state == .poweredOn {
      startScanIfReady()
      if sensorId != nil { connectIfReady() }
    } else if sensorId != nil {
      sensor = nil  // peripherals are invalid after Bluetooth goes off
      send(["event": "link", "state": "connecting"])
    }
  }

  func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    let name =
      (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
    guard let name, !name.isEmpty else { return }
    seen[peripheral.identifier] = peripheral
    let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
    send([
      "event": "found", "id": peripheral.identifier.uuidString, "name": name,
      "hr": services.contains(Self.hrService),
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard peripheral == sensor else { return }
    peripheral.discoverServices([Self.hrService])
  }

  func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    guard peripheral == sensor else { return }
    central.connect(peripheral, options: nil)
  }

  func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    guard peripheral == sensor else { return }
    // Out of range or switched off: wait for it to come back.
    send(["event": "link", "state": "connecting"])
    central.connect(peripheral, options: nil)
  }
}

extension HeartRateBridge: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard peripheral == sensor else { return }
    guard let service = peripheral.services?.first(where: { $0.uuid == Self.hrService }) else {
      send(["event": "link", "state": "noHeartRate"])
      return
    }
    peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    guard peripheral == sensor,
      let measurement = service.characteristics?.first(where: { $0.uuid == Self.hrMeasurement })
    else {
      send(["event": "link", "state": "noHeartRate"])
      return
    }
    peripheral.setNotifyValue(true, for: measurement)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard peripheral == sensor, characteristic.uuid == Self.hrMeasurement else { return }
    send(["event": "link", "state": characteristic.isNotifying ? "connected" : "noHeartRate"])
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    guard peripheral == sensor, characteristic.uuid == Self.hrMeasurement,
      let value = characteristic.value
    else { return }
    send(["event": "data", "bytes": FlutterStandardTypedData(bytes: value)])
  }
}
