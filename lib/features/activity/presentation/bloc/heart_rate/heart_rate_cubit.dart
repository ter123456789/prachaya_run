import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/heart_rate_measurement.dart';
import '../../../domain/services/heart_rate_monitor.dart';

final class HeartRateState extends Equatable {
  const HeartRateState({
    this.available = true,
    this.access,
    this.link = SensorLink.disconnected,
    this.sensor,
    this.bpm,
    this.skinContact,
    this.scanning = false,
    this.found = const [],
  });

  /// False without a sensor port (tests): the UI hides heart rate.
  final bool available;

  /// Null until the first scan asks for Bluetooth.
  final SensorAccess? access;
  final SensorLink link;

  /// The sensor in use (connected or reconnecting).
  final HeartRateSensor? sensor;

  /// The latest reading; null when none arrived lately.
  final int? bpm;
  final bool? skinContact;
  final bool scanning;

  /// Devices seen by the current scan, heart-rate sensors first.
  final List<HeartRateSensor> found;

  bool get connected => link == SensorLink.connected;

  HeartRateState copyWith({
    SensorAccess? access,
    SensorLink? link,
    HeartRateSensor? Function()? sensor,
    int? Function()? bpm,
    bool? Function()? skinContact,
    bool? scanning,
    List<HeartRateSensor>? found,
  }) => HeartRateState(
    available: available,
    access: access ?? this.access,
    link: link ?? this.link,
    sensor: sensor == null ? this.sensor : sensor(),
    bpm: bpm == null ? this.bpm : bpm(),
    skinContact: skinContact == null ? this.skinContact : skinContact(),
    scanning: scanning ?? this.scanning,
    found: found ?? this.found,
  );

  @override
  List<Object?> get props => [
    available,
    access,
    link,
    sensor,
    bpm,
    skinContact,
    scanning,
    found,
  ];
}

/// Pairs the heart-rate sensor and shows its live reading. App-level: the
/// sensor stays connected across pages, and RecordBloc reads the same
/// monitor while recording. Without a monitor it stays [HeartRateState.available]
/// false and does nothing.
class HeartRateCubit extends Cubit<HeartRateState> {
  HeartRateCubit(
    this._monitor, {
    this.staleAfter = const Duration(seconds: 5),
    this.scanFor = const Duration(seconds: 20),
  }) : super(HeartRateState(available: _monitor != null));

  final HeartRateMonitor? _monitor;

  /// A reading older than this shows as "--".
  final Duration staleAfter;

  /// A scan stops by itself after this long.
  final Duration scanFor;

  StreamSubscription<SensorStatus>? _statusSub;
  StreamSubscription<HeartRateReading>? _readingSub;
  StreamSubscription<List<HeartRateSensor>>? _scanSub;
  Timer? _stale;
  Timer? _scanTimer;

  /// Listens to the monitor and reconnects the remembered sensor.
  Future<void> start() async {
    final monitor = _monitor;
    if (monitor == null) return;
    _statusSub ??= monitor.status.listen(_onStatus);
    _readingSub ??= monitor.readings.listen(_onReading);
    await monitor.reconnect();
  }

  Future<void> scan() async {
    final monitor = _monitor;
    if (monitor == null || state.scanning) return;
    final access = await monitor.requestAccess();
    if (isClosed) return;
    emit(state.copyWith(access: access, found: const []));
    if (access != SensorAccess.granted) return;
    emit(state.copyWith(scanning: true));
    _scanSub = monitor.scan().listen(
      (devices) {
        if (!isClosed) emit(state.copyWith(found: _sorted(devices)));
      },
      onError: (Object _) => stopScan(),
      onDone: stopScan,
    );
    _scanTimer = Timer(scanFor, stopScan);
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final sub = _scanSub;
    _scanSub = null;
    if (!isClosed && state.scanning) emit(state.copyWith(scanning: false));
    await sub?.cancel();
  }

  Future<void> connect(HeartRateSensor sensor) async {
    final monitor = _monitor;
    if (monitor == null) return;
    // Not awaited: the scan's teardown need not hold up the connection.
    unawaited(stopScan());
    emit(
      state.copyWith(
        link: SensorLink.connecting,
        sensor: () => sensor,
        bpm: () => null,
      ),
    );
    await monitor.connect(sensor);
  }

  /// Stops using the sensor (and forgets it).
  Future<void> disconnect() async {
    _stale?.cancel();
    emit(
      state.copyWith(
        link: SensorLink.disconnected,
        sensor: () => null,
        bpm: () => null,
        skinContact: () => null,
      ),
    );
    await _monitor?.disconnect();
  }

  void _onStatus(SensorStatus status) {
    if (isClosed) return;
    final live = status.link == SensorLink.connected;
    if (!live) _stale?.cancel();
    emit(
      state.copyWith(
        link: status.link,
        sensor: () => status.sensor,
        bpm: live ? null : () => null,
      ),
    );
  }

  void _onReading(HeartRateReading reading) {
    if (isClosed) return;
    _stale?.cancel();
    _stale = Timer(staleAfter, () {
      if (!isClosed) emit(state.copyWith(bpm: () => null));
    });
    emit(
      state.copyWith(
        bpm: () => reading.isUsable ? reading.bpm : null,
        skinContact: () => reading.skinContact,
      ),
    );
  }

  /// Heart-rate sensors first, then by name.
  static List<HeartRateSensor> _sorted(List<HeartRateSensor> devices) =>
      [...devices]..sort((a, b) {
        if (a.advertisesHeartRate != b.advertisesHeartRate) {
          return a.advertisesHeartRate ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  @override
  Future<void> close() async {
    _stale?.cancel();
    _scanTimer?.cancel();
    await _scanSub?.cancel();
    await _statusSub?.cancel();
    await _readingSub?.cancel();
    return super.close();
  }
}
