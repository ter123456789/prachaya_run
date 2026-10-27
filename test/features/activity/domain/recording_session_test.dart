import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/recording_session.dart';

import '../../../helpers/fakes.dart';

void main() {
  RecordingSession newSession() =>
      RecordingSession(type: ActivityType.run, startedAt: t0);

  test('accumulates distance between accepted points', () {
    final session = newSession()
      ..addPoint(pointAt(0))
      ..addPoint(pointAt(1))
      ..addPoint(pointAt(2));
    expect(session.distanceMeters, closeTo(222.4, 0.5));
  });

  test('drops inaccurate fixes and jitter', () {
    final session = newSession();
    expect(session.addPoint(pointAt(0)), isTrue);
    expect(session.addPoint(pointAt(1, accuracy: 80)), isFalse);
    expect(session.addPoint(pointAt(0)), isFalse); // 0 m step
    expect(session.distanceMeters, 0);
  });

  test('moving time excludes paused time and pause starts a new segment', () {
    final session = newSession()..addPoint(pointAt(0));
    session.pause(t0.add(const Duration(minutes: 10)));
    expect(session.addPoint(pointAt(1)), isFalse);
    session.resume(t0.add(const Duration(minutes: 15)));
    session.addPoint(pointAt(5));

    expect(
      session.movingTime(t0.add(const Duration(minutes: 20))),
      const Duration(minutes: 15),
    );
    expect(session.segments, hasLength(2));
    // The gap across the pause is not counted as distance.
    expect(session.distanceMeters, 0);
  });

  test('elevation gain ignores small noise', () {
    final session = newSession();
    final altitudes = [10.0, 11.0, 10.0, 15.0, 14.0, 20.0];
    for (var i = 0; i < altitudes.length; i++) {
      session.addPoint(pointAt(i, altitude: altitudes[i]));
    }
    expect(session.elevationGainMeters, 10); // 10→15, 15→20
  });

  test('toActivity drops empty segments and keeps totals', () {
    final session = newSession()
      ..addPoint(pointAt(0))
      ..addPoint(pointAt(1));
    final end = t0.add(const Duration(minutes: 1));
    session
      ..pause(end)
      ..resume(end);
    final activity = session.toActivity(id: 'a', title: 'x', endedAt: end);

    expect(activity.segments, hasLength(1));
    expect(activity.distanceMeters, closeTo(session.distanceMeters, 1e-9));
    expect(activity.movingTime, const Duration(minutes: 1));
  });

  test('laps mark distance and moving time; not while paused', () {
    final session = newSession()
      ..addPoint(pointAt(0))
      ..addPoint(pointAt(2));
    expect(session.lapNumber, 1);
    expect(session.lap(t0.add(const Duration(minutes: 1))), isTrue);
    expect(session.lapNumber, 2);
    expect(session.laps.single.distanceMeters, closeTo(222.4, 0.5));
    expect(session.laps.single.movingTime, const Duration(minutes: 1));

    // Nothing covered since the last lap: ignored.
    expect(session.lap(t0.add(const Duration(minutes: 2))), isFalse);

    session.pause(t0.add(const Duration(minutes: 2)));
    session.addPoint(pointAt(4));
    expect(session.lap(t0.add(const Duration(minutes: 3))), isFalse);
    expect(session.lapNumber, 2);
  });

  group('vehicle', () {
    DateTime at(int second) => t0.add(Duration(seconds: second));

    test('pauseFrom drops the ride and its time', () {
      final session = newSession();
      journey([(60, 3.5), (30, 15)]).forEach(session.addPoint);
      session.pauseFrom(at(60), at(90));

      expect(session.isPaused, isTrue);
      expect(session.distanceMeters, closeTo(59 * 3.5, 0.5));
      expect(session.movingTime(at(600)), const Duration(seconds: 60));
      expect(session.segments.last.last.timestamp, at(60));
    });

    test('pauseFrom drops laps ended during the ride', () {
      final session = newSession();
      journey([(60, 3.5), (30, 15)]).forEach(session.addPoint);
      expect(session.lap(at(80)), isTrue);
      session.pauseFrom(at(60), at(90));
      expect(session.laps, isEmpty);
      expect(session.lapNumber, 1);
    });

    test('resumeFrom adds the fixes since getting out', () {
      final session = newSession();
      journey([(60, 3.5), (30, 15)]).forEach(session.addPoint);
      session.pauseFrom(at(60), at(90));
      final after = journey([(60, 3)], startSecond: 180, startMeters: 1000);
      session.resumeFrom(at(180), after, at(240));

      expect(session.isPaused, isFalse);
      expect(session.segments, hasLength(2));
      expect(session.distanceMeters, closeTo(59 * 3.5 + 59 * 3, 0.5));
      expect(session.movingTime(at(240)), const Duration(minutes: 2));
    });
  });
}
