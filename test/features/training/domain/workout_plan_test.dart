import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/recording_session.dart';
import 'package:prachaya_run/features/activity/domain/usecases/save_activity.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:prachaya_run/features/training/domain/services/workout_plan.dart';
import 'package:prachaya_run/features/training/domain/usecases/complete_workout.dart';

import '../../../helpers/fakes.dart';

PlannedWorkout _w(
  String id,
  DateTime at, {
  WorkoutType type = WorkoutType.tempo,
  double meters = 7000,
  int? min = 315,
  int? max = 330,
  String? done,
}) => PlannedWorkout(
  id: id,
  type: type,
  title: id,
  scheduledAt: at,
  distanceMeters: type == WorkoutType.rest ? 0 : meters,
  paceMinSecPerKm: type == WorkoutType.rest ? null : min,
  paceMaxSecPerKm: type == WorkoutType.rest ? null : max,
  completedActivityId: done,
);

ActivitySummary _run(String id, DateTime at, {double meters = 7000}) =>
    ActivitySummary(
      id: id,
      type: ActivityType.run,
      title: id,
      startedAt: at,
      movingTime: const Duration(minutes: 40),
      distanceMeters: meters,
      elevationGainMeters: 0,
    );

void main() {
  // Thursday 14 May 2026, 10:00.
  final now = DateTime(2026, 5, 14, 10);

  group('phases', () {
    test('tempo 7 km: warm-up 1 km, main 5 km, cool-down 1 km', () {
      final phases = workoutPhases(_w('t', now));
      expect(phases, [
        const WorkoutPhase(
          kind: PhaseKind.warmUp,
          distanceMeters: 1000,
          paceSecPerKm: 390, // slow end + 60 s
          zoneLow: 1,
          zoneHigh: 2,
        ),
        const WorkoutPhase(
          kind: PhaseKind.main,
          distanceMeters: 5000,
          paceSecPerKm: 315,
          zoneLow: 4,
          zoneHigh: 4,
        ),
        const WorkoutPhase(
          kind: PhaseKind.coolDown,
          distanceMeters: 1000,
          paceSecPerKm: 420, // slow end + 90 s
          zoneLow: 1,
          zoneHigh: 1,
        ),
      ]);
      final total = phases.fold<double>(0, (s, p) => s + p.distanceMeters);
      expect(total, 7000);
    });

    test('easy, long and short sessions are one block; rest has none', () {
      expect(workoutPhases(_w('e', now, type: WorkoutType.easy)), hasLength(1));
      expect(
        workoutPhases(_w('s', now, meters: 2500)).single.distanceMeters,
        2500,
      );
      expect(workoutPhases(_w('r', now, type: WorkoutType.rest)), isEmpty);
      expect(workoutPhases(_w('n', now, min: null, max: null)), isEmpty);
    });

    test('estimate = distance × middle of the pace range', () {
      // 7 km × 322.5 s.
      expect(
        estimatedDuration(_w('t', now)),
        const Duration(minutes: 37, seconds: 38),
      );
      expect(estimatedDuration(_w('r', now, type: WorkoutType.rest)), isNull);
    });
  });

  group('validation (same as the server)', () {
    test('accepts sensible sessions', () {
      expect(isValidWorkout(_w('t', now)), isTrue);
      expect(isValidWorkout(_w('r', now, type: WorkoutType.rest)), isTrue);
      expect(isValidWorkout(_w('n', now, min: null, max: null)), isTrue);
    });

    test('rejects broken ones', () {
      expect(isValidWorkout(_w('a', now).copyWith(title: '  ')), isFalse);
      expect(isValidWorkout(_w('b', now, min: 340, max: 330)), isFalse);
      expect(isValidWorkout(_w('c', now, min: 315, max: null)), isFalse);
      expect(isValidWorkout(_w('d', now, min: 100, max: 330)), isFalse);
      expect(isValidWorkout(_w('e', now, meters: 0)), isFalse);
      expect(
        isValidWorkout(
          _w('f', now, type: WorkoutType.rest).copyWith(distanceMeters: 5000),
        ),
        isFalse,
      );
    });
  });

  group('week', () {
    final mon = DateTime(2026, 5, 11, 18, 30);
    final workouts = [
      _w('mon', mon, done: 'run-mon'),
      _w('tue', mon.add(const Duration(days: 1)), type: WorkoutType.rest),
      _w('thu', DateTime(2026, 5, 14, 18, 30), meters: 5000),
      _w('fri', DateTime(2026, 5, 15, 18), meters: 10000, done: 'deleted-run'),
      _w('next', DateTime(2026, 5, 18, 7)),
    ];
    final activities = [_run('run-mon', mon, meters: 7200)];

    test('Monday–Sunday around today, with what is done', () {
      final week = TrainingWeek.from(workouts, activities, now);
      expect(week.start, DateTime(2026, 5, 11));
      expect(week.end, DateTime(2026, 5, 17));
      expect(week.days, hasLength(7));
      expect(week.days[1].isRestDay, isTrue);
      expect(week.plannedSessions, 3); // rest days do not count
      // The Friday run was deleted, so that session is not done.
      expect(week.completedSessions, 1);
      expect(week.plannedMeters, 22000);
      expect(week.completedMeters, 7200);
      expect(week.progress, closeTo(7200 / 22000, 1e-9));
      expect(week.weekNumber, 20);
    });

    test('ISO week numbers across a year boundary', () {
      int week(DateTime d) =>
          TrainingWeek.from(const [], const [], d).weekNumber;
      expect(week(DateTime(2026, 1, 1)), 1); // Thursday
      expect(week(DateTime(2027, 1, 1)), 53); // Friday of 2026-W53
      expect(week(DateTime(2026, 10, 12)), 42);
    });

    test("today's session and the upcoming ones", () {
      expect(todaysWorkout(workouts, now)!.id, 'thu');
      expect(
        [for (final w in upcomingWorkouts(workouts, now)) w.id],
        ['fri', 'next'],
      );
    });
  });

  group('completion', () {
    test('a run ticks off the open session of that day closest in time', () {
      final early = _w('early', DateTime(2026, 5, 14, 6));
      final late = _w('late', DateTime(2026, 5, 14, 19));
      final rest = _w(
        'rest',
        DateTime(2026, 5, 14, 18),
        type: WorkoutType.rest,
      );
      final run = _run('r', DateTime(2026, 5, 14, 18, 10));
      expect(workoutFulfilledBy(run, [early, late, rest])!.id, 'late');
      expect(
        workoutFulfilledBy(run, [
          early,
          late.copyWith(completedActivityId: () => 'x'),
        ])!.id,
        'early',
      );
      expect(
        workoutFulfilledBy(_run('r', DateTime(2026, 5, 15)), [early]),
        isNull,
      );
      final ride = ActivitySummary(
        id: 'ride',
        type: ActivityType.ride,
        title: 'ride',
        startedAt: DateTime(2026, 5, 14, 19),
        movingTime: const Duration(hours: 1),
        distanceMeters: 20000,
        elevationGainMeters: 0,
      );
      expect(workoutFulfilledBy(ride, [late]), isNull);
    });

    test(
      'saving a run links the primary shoe and completes the session',
      () async {
        final activities = InMemoryActivityRepository();
        final workouts = InMemoryWorkoutRepository();
        await workouts.save(_w('plan', t0.add(const Duration(minutes: 5))));
        final session = RecordingSession(type: ActivityType.run, startedAt: t0);
        for (var i = 0; i < 10; i++) {
          session.addPoint(pointAt(i));
        }
        final save = SaveActivity(
          activities,
          newId: () => 'saved',
          defaultShoe: (type) async =>
              type == ActivityType.run ? 'shoe-1' : null,
          onSaved: [CompleteWorkoutForActivity(workouts).call],
        );
        await save(
          session,
          title: 'วิ่ง',
          endedAt: t0.add(const Duration(minutes: 5)),
        );
        expect(activities.store['saved']!.shoeId, 'shoe-1');
        expect(workouts.store['plan']!.completedActivityId, 'saved');
      },
    );
  });

  test('templates are valid starting points', () {
    for (final type in WorkoutType.values) {
      final t = templateFor(type);
      final w = PlannedWorkout(
        id: 'x',
        type: type,
        title: t.title,
        scheduledAt: now,
        distanceMeters: t.distanceMeters,
        paceMinSecPerKm: t.paceMinSecPerKm,
        paceMaxSecPerKm: t.paceMaxSecPerKm,
      );
      expect(isValidWorkout(w), isTrue, reason: '$type');
    }
  });
}
