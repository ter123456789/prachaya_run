import 'heart_rate_measurement.dart';

enum SensorAccess {
  granted,

  /// Bluetooth permission refused.
  denied,
  bluetoothOff,

  /// No Bluetooth LE on this device.
  unsupported,
}

enum SensorLink {
  disconnected,

  /// Connecting, or waiting for the sensor to come back in range.
  connecting,
  connected,

  /// Connected, but the device offers no heart-rate service (e.g. a watch
  /// whose broadcast mode is off).
  noHeartRate,
}

/// A Bluetooth device seen while scanning, or the remembered one.
class HeartRateSensor {
  const HeartRateSensor({
    required this.id,
    required this.name,
    this.advertisesHeartRate = false,
  });

  /// Platform id: a MAC address on Android, a per-phone UUID on iOS.
  final String id;
  final String name;

  /// Advertises the heart-rate service. Some wristbands only reveal it
  /// after connecting, so other devices are offered too.
  final bool advertisesHeartRate;

  @override
  bool operator ==(Object other) => other is HeartRateSensor && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HeartRateSensor($name, $id)';
}

class SensorStatus {
  const SensorStatus(this.link, [this.sensor]);

  final SensorLink link;

  /// The sensor in use; null when none is chosen.
  final HeartRateSensor? sensor;

  @override
  bool operator ==(Object other) =>
      other is SensorStatus && other.link == link && other.sensor == sensor;

  @override
  int get hashCode => Object.hash(link, sensor);
}

/// Port for a Bluetooth LE heart-rate sensor (chest strap, or a watch that
/// broadcasts its heart rate).
abstract interface class HeartRateMonitor {
  Future<SensorAccess> requestAccess();

  /// Nearby devices, growing while listened to; cancelling stops the scan.
  Stream<List<HeartRateSensor>> scan();

  /// Connects and keeps reconnecting (out of range, sensor off) until
  /// [disconnect]. The sensor is remembered for [reconnect].
  Future<void> connect(HeartRateSensor sensor);

  /// Connects to the remembered sensor, if any.
  Future<void> reconnect();

  /// Disconnects and forgets the sensor.
  Future<void> disconnect();

  Stream<SensorStatus> get status;

  Stream<HeartRateReading> get readings;
}
