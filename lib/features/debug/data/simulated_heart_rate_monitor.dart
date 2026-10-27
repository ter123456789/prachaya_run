import 'dart:async';
import 'dart:math' as math;

import '../../activity/domain/services/heart_rate_measurement.dart';
import '../../activity/domain/services/heart_rate_monitor.dart';
import 'virtual_clock.dart';

/// The real sensor, plus a pretend one listed first in every scan, so heart
/// rate can be tried on a simulator (no Bluetooth there). Connected to it,
/// a reading arrives every simulated second: a warm-up from 100 bpm, then
/// a slow swing between about 140 and 170.
class SimulatedHeartRateMonitor implements HeartRateMonitor {
  SimulatedHeartRateMonitor(this._real, this._clock) {
    // Lives as long as the app, like the monitor itself.
    _real.status.listen((s) {
      if (!_simulating) _status.add(s);
    });
    _real.readings.listen((r) {
      if (!_simulating) _readings.add(r);
    });
  }

  static const sensor = HeartRateSensor(
    id: 'debug-hr',
    name: 'เซนเซอร์จำลอง (debug)',
    advertisesHeartRate: true,
  );

  final HeartRateMonitor _real;
  final VirtualClock _clock;
  final _status = StreamController<SensorStatus>.broadcast();
  final _readings = StreamController<HeartRateReading>.broadcast();
  bool _simulating = false;
  Timer? _timer;
  DateTime? _since;

  @override
  Stream<SensorStatus> get status => _status.stream;

  @override
  Stream<HeartRateReading> get readings => _readings.stream;

  @override
  Future<SensorAccess> requestAccess() async {
    final access = await _real.requestAccess();
    // The pretend sensor works without Bluetooth.
    return access == SensorAccess.granted ? access : SensorAccess.granted;
  }

  @override
  Stream<List<HeartRateSensor>> scan() async* {
    yield const [sensor];
    final real = await _real.requestAccess();
    if (real != SensorAccess.granted) return;
    yield* _real.scan().map((found) => [sensor, ...found]);
  }

  @override
  Future<void> connect(HeartRateSensor chosen) async {
    if (chosen != sensor) {
      _stopSimulation();
      return _real.connect(chosen);
    }
    await _real.disconnect();
    _simulating = true;
    _since = _clock.now();
    _status.add(const SensorStatus(SensorLink.connected, sensor));
    _timer?.cancel();
    var last = -1;
    // Checked often, so a sped-up clock still gets about one reading per
    // simulated second.
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final t = _clock.now().difference(_since!).inSeconds;
      if (t == last) return;
      last = t;
      final warmUp = math.min(t / 120, 1.0);
      final swing = 15 * math.sin(t * 2 * math.pi / 180);
      final bpm = (100 + warmUp * (155 - 100) + warmUp * swing).round();
      _readings.add(HeartRateReading(bpm: bpm, skinContact: true));
    });
  }

  @override
  Future<void> reconnect() => _real.reconnect();

  @override
  Future<void> disconnect() async {
    if (_simulating) {
      _stopSimulation();
      _status.add(const SensorStatus(SensorLink.disconnected));
      return;
    }
    await _real.disconnect();
  }

  void _stopSimulation() {
    _timer?.cancel();
    _timer = null;
    _simulating = false;
  }
}
