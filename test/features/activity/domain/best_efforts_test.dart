import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/services/best_efforts.dart';

const _metersPerDegree = 111195.0;

/// Points every 10 s going north; [speeds] gives m/s per step.
List<TrackPoint> _segment(
  DateTime start,
  double startMeters,
  List<double> speeds,
) {
  var m = startMeters;
  final points = [
    TrackPoint(
      latitude: 13.7 + m / _metersPerDegree,
      longitude: 100.5,
      timestamp: start,
    ),
  ];
  for (var i = 0; i < speeds.length; i++) {
    m += speeds[i] * 10;
    points.add(
      TrackPoint(
        latitude: 13.7 + m / _metersPerDegree,
        longitude: 100.5,
        timestamp: start.add(Duration(seconds: (i + 1) * 10)),
      ),
    );
  }
  return points;
}

Activity _activity(
  List<List<TrackPoint>> segments, {
  ActivityType type = ActivityType.run,
}) => Activity(
  id: 'a',
  type: type,
  title: 't',
  startedAt: segments.first.first.timestamp,
  endedAt: segments.last.last.timestamp,
  movingTime: Duration.zero,
  segments: segments,
);

void main() {
  final t0 = DateTime.utc(2026, 10, 10, 6);

  test('steady pace: 5 km takes distance ÷ speed', () {
    final run = _activity([_segment(t0, 0, List.filled(200, 3.0))]);
    expect(bestEffort(run, 5000)!.inMilliseconds, closeTo(1666667, 1500));
  });

  test('finds the fastest window, not the first one', () {
    // 2 km slow (2 m/s), then 2 km fast (4 m/s).
    final run = _activity([
      _segment(t0, 0, [...List.filled(100, 2.0), ...List.filled(50, 4.0)]),
    ]);
    expect(bestEffort(run, 1000)!.inMilliseconds, closeTo(250000, 1500));
  });

  test('pauses between segments are not counted', () {
    // 1 km, a 30 min pause, then 1 km more, all at 4 m/s.
    final first = _segment(t0, 0, List.filled(25, 4.0));
    final second = _segment(
      t0.add(const Duration(minutes: 40)),
      1000,
      List.filled(25, 4.0),
    );
    final run = _activity([first, second]);
    expect(bestEffort(run, 1900)!.inMilliseconds, closeTo(475000, 1500));
  });

  test('null when the track is shorter than the distance', () {
    final run = _activity([_segment(t0, 0, List.filled(10, 3.0))]);
    expect(bestEffort(run, 5000), isNull);
  });

  test('personal bests take the fastest run and ignore rides', () {
    final slow = _activity([_segment(t0, 0, List.filled(400, 3.0))]);
    final fast = _activity([_segment(t0, 0, List.filled(200, 3.5))]);
    final ride = _activity([
      _segment(t0, 0, List.filled(400, 9.0)),
    ], type: ActivityType.ride);
    final bests = PersonalBests.from([slow, fast, ride]);
    expect(bests.fiveK!.inMilliseconds, closeTo(5000 / 3.5 * 1000, 1500));
    expect(bests.tenK!.inMilliseconds, closeTo(10000 / 3 * 1000, 1500));
    expect(PersonalBests.from([ride]).isEmpty, isTrue);
  });
}
