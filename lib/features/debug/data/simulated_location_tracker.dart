import 'dart:async';

import '../../activity/domain/entities/activity_type.dart';
import '../../activity/domain/entities/track_point.dart';
import '../../activity/domain/services/location_tracker.dart';
import '../domain/entities/gps_simulation.dart';
import '../domain/services/route_simulator.dart';
import 'virtual_clock.dart';

/// Real GPS unless the debug simulation is on; then emits one fix per
/// simulated second along the chosen route.
class SimulatedLocationTracker implements LocationTracker {
  SimulatedLocationTracker(this._real, this._clock);

  final LocationTracker _real;
  final VirtualClock _clock;

  GpsSimulation settings = const GpsSimulation();
  StreamController<TrackPoint>? _active;
  RouteSimulator? _simulator;
  double _meters = 0;

  void dropSignal() => _active?.addError(StateError('simulated GPS loss'));

  @override
  Future<LocationAccess> requestAccess() async {
    if (!settings.enabled) return _real.requestAccess();
    // A permission request starts a new recording: begin at the route start.
    _simulator = RouteSimulator(settings.route, noise: settings.noise);
    _meters = 0;
    return settings.access;
  }

  @override
  Stream<TrackPoint> watch(ActivityType type) {
    if (!settings.enabled) return _real.watch(type);
    final simulator = _simulator ??= RouteSimulator(
      settings.route,
      noise: settings.noise,
    );
    Timer? timer;
    late final StreamController<TrackPoint> controller;
    controller = StreamController<TrackPoint>(
      onListen: () {
        final perTick = Duration(microseconds: 1000000 ~/ settings.speed);
        timer = Timer.periodic(perTick, (_) {
          // Resuming after a pause continues where the runner stopped.
          _meters += 1000 / settings.paceSecondsPerKm;
          controller.add(simulator.pointAt(_meters, _clock.now()));
        });
      },
      onCancel: () {
        timer?.cancel();
        if (identical(_active, controller)) _active = null;
      },
    );
    return (_active = controller).stream;
  }
}
