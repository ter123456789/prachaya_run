import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:prachaya_run/features/training/domain/services/workout_plan.dart';
import 'package:prachaya_run/features/training/presentation/bloc/training_cubit.dart';
import 'package:prachaya_run/features/training/presentation/bloc/workout_draft_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  final now = DateTime(2026, 5, 14, 10); // Thursday

  PlannedWorkout tempo(String id, DateTime at, {String? done}) =>
      PlannedWorkout(
        id: id,
        type: WorkoutType.tempo,
        title: 'Tempo',
        location: 'สวนลุมพินี',
        scheduledAt: at,
        distanceMeters: 7000,
        paceMinSecPerKm: 315,
        paceMaxSecPerKm: 330,
        completedActivityId: done,
      );

  group('TrainingCubit', () {
    late InMemoryWorkoutRepository workouts;
    late InMemoryActivityRepository activities;

    setUp(() {
      workouts = InMemoryWorkoutRepository();
      activities = InMemoryActivityRepository();
    });

    test('load builds the week, focus, upcoming and done state', () async {
      final run = sampleActivity();
      activities.store[run.id] = run;
      await workouts.save(tempo('today', DateTime(2026, 5, 14, 18, 30)));
      await workouts.save(tempo('mon', DateTime(2026, 5, 11, 7), done: run.id));
      await workouts.save(tempo('sat', DateTime(2026, 5, 16, 7)));
      final cubit = TrainingCubit(workouts, activities, clock: () => now);
      addTearDown(cubit.close);
      await cubit.load();
      final s = cubit.state;
      expect(s.loaded, isTrue);
      expect(s.focus!.id, 'today');
      expect([for (final w in s.upcoming) w.id], ['sat']);
      expect(s.week.plannedSessions, 3);
      expect(s.week.completedSessions, 1);
      expect(s.isDone(workouts.store['mon']!), isTrue);
      expect(s.recentLocations, ['สวนลุมพินี']);
    });

    blocTest<TrainingCubit, TrainingState>(
      'selecting a day changes the focus card',
      build: () => TrainingCubit(workouts, activities, clock: () => now),
      setUp: () async => workouts.save(tempo('sat', DateTime(2026, 5, 16, 7))),
      act: (c) async {
        await c.load();
        c.selectDay(DateTime(2026, 5, 16));
      },
      verify: (c) => expect(c.state.focus!.id, 'sat'),
    );

    blocTest<TrainingCubit, TrainingState>(
      'create, edit and delete',
      build: () => TrainingCubit(workouts, activities, clock: () => now),
      act: (c) async {
        await c.save(tempo('w', DateTime(2026, 5, 15, 6)));
        await c.save(
          tempo('w', DateTime(2026, 5, 15, 6)).copyWith(title: 'Edited'),
        );
        await c.delete('w');
      },
      verify: (c) => expect(c.state.workouts, isEmpty),
      expect: () => [
        isA<TrainingState>().having(
          (s) => s.workouts.single.title,
          'title',
          'Tempo',
        ),
        isA<TrainingState>().having(
          (s) => s.workouts.single.title,
          'title',
          'Edited',
        ),
        isA<TrainingState>().having((s) => s.workouts, 'workouts', isEmpty),
      ],
    );
  });

  group('WorkoutDraftCubit', () {
    WorkoutDraftCubit draft() =>
        WorkoutDraftCubit(day: DateTime(2026, 5, 16), newId: () => 'new');

    test('starts as a tempo session at 18:30 on the chosen day', () {
      final c = draft();
      addTearDown(c.close);
      final w = c.state.workout;
      expect(w.id, 'new');
      expect(w.type, WorkoutType.tempo);
      expect(w.scheduledAt, DateTime(2026, 5, 16, 18, 30));
      expect(c.state.phases, hasLength(3));
      expect(c.state.valid, isTrue);
    });

    test('changing type loads its template but keeps a custom title', () {
      final c = draft();
      addTearDown(c.close);
      c.setType(WorkoutType.long);
      expect(c.state.workout.title, templateFor(WorkoutType.long).title);
      expect(c.state.workout.distanceMeters, 15000);
      c.setTitle('My long run');
      c.setType(WorkoutType.easy);
      expect(c.state.workout.title, 'My long run');
      c.setType(WorkoutType.rest);
      expect(c.state.workout.distanceMeters, 0);
      expect(c.state.workout.paceMinSecPerKm, isNull);
      expect(c.state.valid, isTrue);
    });

    test('steppers, day and time', () {
      final c = draft();
      addTearDown(c.close);
      c.stepDistance(1);
      expect(c.state.workout.distanceMeters, 7500);
      for (var i = 0; i < 30; i++) {
        c.stepDistance(-1);
      }
      expect(c.state.workout.distanceMeters, 500);
      c.stepPace(-1);
      expect(c.state.workout.paceMinSecPerKm, 310);
      expect(c.state.workout.paceMaxSecPerKm, 325);
      c.setDay(DateTime(2026, 5, 20));
      c.setTime(6, 15);
      expect(c.state.workout.scheduledAt, DateTime(2026, 5, 20, 6, 15));
      c.setLocation('ลู่วิ่งในร่ม');
      expect(c.state.workout.location, 'ลู่วิ่งในร่ม');
    });

    test('submit refuses an invalid draft and flags the error', () {
      final c = draft();
      addTearDown(c.close);
      c.setTitle('');
      expect(c.submit(), isNull);
      expect(c.state.error, isTrue);
      c.setTitle('Tempo');
      expect(c.submit()!.title, 'Tempo');
    });

    test('editing keeps the id and is not new', () {
      final existing = tempo('old', DateTime(2026, 5, 15, 7));
      final c = WorkoutDraftCubit(day: now, existing: existing);
      addTearDown(c.close);
      expect(c.state.isNew, isFalse);
      expect(c.state.workout, existing);
    });
  });
}
