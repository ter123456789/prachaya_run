import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder.dart';
import 'package:prachaya_run/features/reminders/domain/services/reminder_plan.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';

PlannedWorkout _w(
  String id,
  DateTime at, {
  WorkoutType type = WorkoutType.tempo,
  String? done,
}) => PlannedWorkout(
  id: id,
  type: type,
  title: id,
  scheduledAt: at,
  distanceMeters: type == WorkoutType.rest ? 0 : 5000,
  completedActivityId: done,
);

void main() {
  final now = DateTime(2026, 10, 13, 12);

  group('workout reminders', () {
    test('lead time before each session still ahead, soonest first', () {
      final due = dueWorkoutReminders(
        [
          _w('later', DateTime(2026, 10, 15, 6)),
          _w('soon', DateTime(2026, 10, 13, 18)),
        ],
        now: now,
        leadMinutes: 30,
      );
      expect(due.map((d) => d.workout.id), ['soon', 'later']);
      expect(due.first.at, DateTime(2026, 10, 13, 17, 30));
    });

    test('rest days, done sessions and passed reminders are skipped', () {
      final due = dueWorkoutReminders(
        [
          _w('rest', DateTime(2026, 10, 14, 6), type: WorkoutType.rest),
          _w('done', DateTime(2026, 10, 14, 7), done: 'a1'),
          _w('past', DateTime(2026, 10, 12, 7)),
          // Starts in 20 min: its 30-min reminder time has passed.
          _w('too-close', DateTime(2026, 10, 13, 12, 20)),
          _w('ok', DateTime(2026, 10, 14, 8)),
        ],
        now: now,
        leadMinutes: 30,
      );
      expect(due.map((d) => d.workout.id), ['ok']);
    });

    test('capped for the iOS pending-notification limit', () {
      final many = [
        for (var i = 0; i < 100; i++)
          _w('w$i', DateTime(2026, 10, 14).add(Duration(hours: i))),
      ];
      final due = dueWorkoutReminders(many, now: now, leadMinutes: 30);
      expect(due, hasLength(kMaxWorkoutReminders));
      expect(due.first.workout.id, 'w0');
    });

    test('ids are stable per workout and clear of the fixed ids', () {
      const id = '9e8d7c6b-5a49-4382-9170-6f5e4d3c2b1a';
      expect(workoutReminderId(id), workoutReminderId(id));
      expect(workoutReminderId(id), isNot(workoutReminderId('${id}x')));
      for (var i = 0; i < 500; i++) {
        final n = workoutReminderId('w$i');
        expect(n, greaterThanOrEqualTo(10));
        expect(n, lessThanOrEqualTo(0x7fffffff));
      }
    });
  });

  test('weekly goal is reached only when crossing it', () {
    expect(
      reachedWeeklyGoal(
        beforeMeters: 19000,
        afterMeters: 21000,
        goalMeters: 20000,
      ),
      isTrue,
    );
    expect(
      reachedWeeklyGoal(
        beforeMeters: 21000,
        afterMeters: 25000,
        goalMeters: 20000,
      ),
      isFalse,
    );
    expect(
      reachedWeeklyGoal(
        beforeMeters: 1000,
        afterMeters: 5000,
        goalMeters: 20000,
      ),
      isFalse,
    );
  });

  test('next morning is today before 06:00, else tomorrow', () {
    expect(nextMorning(DateTime(2026, 10, 13, 5)), DateTime(2026, 10, 13, 6));
    expect(nextMorning(DateTime(2026, 10, 13, 6)), DateTime(2026, 10, 14, 6));
    expect(nextMorning(DateTime(2026, 10, 31, 22)), DateTime(2026, 11, 1, 6));
  });

  test('tap targets survive the payload round trip', () {
    final day = ScheduleTarget(DateTime(2026, 10, 14, 17, 30));
    expect(day.encode(), 'schedule:2026-10-14');
    expect(ReminderTarget.decode(day.encode()), day);
    expect(ReminderTarget.decode('home'), const HomeTarget());
    expect(ReminderTarget.decode('nonsense'), isNull);
    expect(ReminderTarget.decode(null), isNull);
  });
}
