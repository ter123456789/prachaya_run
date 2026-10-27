import 'dart:async';

import 'package:flutter/services.dart';

import '../../../../core/storage/kv_store.dart';
import '../../domain/services/heart_rate_measurement.dart';
import '../../domain/services/heart_rate_monitor.dart';

/// Bluetooth LE heart-rate sensor through our own platform code, no plugin:
/// `ios/Runner/HeartRateBridge.swift` (CoreBluetooth) and
/// `android/.../HeartRateBridge.kt` (BluetoothGatt).
///
/// Methods on `prachaya/heart_rate`: `access` → granted | denied | off |
/// unsupported, `startScan`, `stopScan`, `connect {id, name}`, `disconnect`.
/// Events on `prachaya/heart_rate/events` (maps with an `event` key):
/// - `found {id, name, hr}`: a named device seen while scanning;
///   `hr` = it advertises the heart-rate service (0x180D).
/// - `link {state}`: connecting | connected | disconnected | noHeartRate.
///   The native side keeps reconnecting after an unexpected drop.
/// - `data {bytes}`: one Heart Rate Measurement (0x2A37) value, decoded
///   here by [parseHeartRateMeasurement].
///
/// The chosen sensor is remembered in `kv` (`settings.hr_sensor`).
class NativeHeartRateMonitor implements HeartRateMonitor {
  NativeHeartRateMonitor(
    this._kv, {
    MethodChannel methods = const MethodChannel('prachaya/heart_rate'),
    EventChannel events = const EventChannel('prachaya/heart_rate/events'),
  }) : _methods = methods,
       _events = events;

  static const _key = 'settings.hr_sensor';

  final KvStore _kv;
  final MethodChannel _methods;
  final EventChannel _events;

  final _status = StreamController<SensorStatus>.broadcast();
  final _readings = StreamController<HeartRateReading>.broadcast();
  final _found = <String, HeartRateSensor>{};
  StreamController<List<HeartRateSensor>>? _scan;
  StreamSubscription<Object?>? _eventSub;
  HeartRateSensor? _sensor;
  SensorStatus _current = const SensorStatus(SensorLink.disconnected);

  /// Starts with the current status, then every change.
  @override
  Stream<SensorStatus> get status {
    StreamSubscription<SensorStatus>? changes;
    late final StreamController<SensorStatus> controller;
    controller = StreamController<SensorStatus>(
      onListen: () {
        controller.add(_current);
        changes = _status.stream.listen(controller.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<HeartRateReading> get readings => _readings.stream;

  @override
  Future<SensorAccess> requestAccess() async {
    try {
      final answer = await _methods.invokeMethod<String>('access');
      return switch (answer) {
        'granted' => SensorAccess.granted,
        'off' => SensorAccess.bluetoothOff,
        'unsupported' => SensorAccess.unsupported,
        _ => SensorAccess.denied,
      };
    } on MissingPluginException {
      return SensorAccess.unsupported;
    }
  }

  @override
  Stream<List<HeartRateSensor>> scan() {
    late final StreamController<List<HeartRateSensor>> controller;
    controller = StreamController<List<HeartRateSensor>>(
      onListen: () async {
        _found.clear();
        _scan = controller;
        _listen();
        await _call('startScan');
      },
      onCancel: () async {
        if (identical(_scan, controller)) _scan = null;
        await _call('stopScan');
      },
    );
    return controller.stream;
  }

  @override
  Future<void> connect(HeartRateSensor sensor) async {
    _sensor = sensor;
    await _kv.write(_key, {'id': sensor.id, 'name': sensor.name});
    _emit(SensorLink.connecting);
    _listen();
    await _call('connect', {'id': sensor.id, 'name': sensor.name});
  }

  @override
  Future<void> reconnect() async {
    final saved = await _kv.read(_key);
    if (saved == null || _sensor != null) return;
    final id = saved['id'] as String?;
    if (id == null) return;
    await connect(
      HeartRateSensor(id: id, name: saved['name'] as String? ?? id),
    );
  }

  @override
  Future<void> disconnect() async {
    _sensor = null;
    await _kv.remove(_key);
    await _call('disconnect');
    _emit(SensorLink.disconnected);
  }

  void _listen() {
    _eventSub ??= _events.receiveBroadcastStream().listen(
      (event) => _onEvent((event as Map).cast<String, Object?>()),
      onError: (Object _) {},
    );
  }

  void _onEvent(Map<String, Object?> e) {
    switch (e['event']) {
      case 'found':
        final id = e['id'] as String?;
        final name = e['name'] as String?;
        if (id == null || name == null || name.isEmpty) return;
        _found[id] = HeartRateSensor(
          id: id,
          name: name,
          advertisesHeartRate: e['hr'] == true,
        );
        _scan?.add(_found.values.toList());
      case 'link':
        if (_sensor == null) return;
        final link = switch (e['state']) {
          'connected' => SensorLink.connected,
          'connecting' => SensorLink.connecting,
          'noHeartRate' => SensorLink.noHeartRate,
          _ => SensorLink.disconnected,
        };
        _emit(link);
      case 'data':
        final bytes = e['bytes'];
        if (bytes is! List<int>) return;
        final reading = parseHeartRateMeasurement(bytes);
        if (reading != null) _readings.add(reading);
    }
  }

  void _emit(SensorLink link) {
    _current = SensorStatus(link, _sensor);
    _status.add(_current);
  }

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _methods.invokeMethod<Object?>(method, args);
    } on PlatformException {
      // Bluetooth off or the device went away: the link event says so.
    } on MissingPluginException {
      // Not wired on this platform (desktop, tests).
    }
  }
}
