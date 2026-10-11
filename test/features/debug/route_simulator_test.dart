import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/recording_session.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/domain/services/route_simulator.dart';

void main() {
  final t0 = DateTime(2026, 10, 11, 6);

  test('recorded distance matches the simulated distance', () {
    for (final route in SimRoute.values) {
      final sim = RouteSimulator(route, noise: false);
      final session = RecordingSession(type: ActivityType.run, startedAt: t0);
      // 5 km at 3 m/s, one fix per second.
      for (var s = 0; s <= 5000 / 3; s++) {
        session.addPoint(sim.pointAt(s * 3.0, t0.add(Duration(seconds: s))));
      }
      expect(session.distanceMeters, closeTo(5000, 60), reason: '$route');
    }
  });

  test('loops come back to the start; open routes turn around', () {
    final loop = RouteSimulator(SimRoute.lumpini, noise: false);
    final start = loop.pointAt(0, t0);
    final lap = loop.pointAt(loop.lapMeters, t0);
    expect(lap.latitude, closeTo(start.latitude, 1e-9));
    expect(lap.longitude, closeTo(start.longitude, 1e-9));

    final climb = RouteSimulator(SimRoute.doiSuthep, noise: false);
    final top = climb.pointAt(climb.lapMeters, t0);
    final back = climb.pointAt(2 * climb.lapMeters, t0);
    expect(top.altitudeMeters, closeTo(1000, 1));
    expect(back.altitudeMeters, closeTo(340, 1));
  });

  test('noise adds jitter and the occasional fix the recorder drops', () {
    final sim = RouteSimulator(SimRoute.lumpini, random: math.Random(1));
    final fixes = [for (var i = 0; i < 2000; i++) sim.pointAt(i * 3.0, t0)];
    final bad = fixes.where((p) => p.accuracyMeters! > 30).length;
    expect(bad, inInclusiveRange(10, 80));
  });
}
