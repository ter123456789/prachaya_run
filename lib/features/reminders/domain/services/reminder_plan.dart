import '../../../training/domain/entities/planned_workout.dart';

/// iOS keeps at most 64 pending local notifications; workouts get these.
const int kMaxWorkoutReminders = 40;

/// Fixed ids for the one-per-kind reminders; workout ids are hashed above.
const int kWeatherReminderId = 1;
const int kWeeklyGoalReminderId = 2;

/// Stable notification id for a workout (FNV-1a, 31 bits, never 0–9).
int workoutReminderId(String workoutId) {
  var hash = 0x811c9dc5;
  for (final unit in workoutId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash < 10 ? hash + 10 : hash;
}

/// A session with the time its reminder fires.
class DueWorkout {
  const DueWorkout(this.workout, this.at);

  final PlannedWorkout workout;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is DueWorkout && other.workout == workout && other.at == at;

  @override
  int get hashCode => Object.hash(workout, at);
}

/// Sessions to remind about, soonest first: [leadMinutes] before each one
/// that is still ahead. Rest days, done sessions and reminders already past
/// are left out.
List<DueWorkout> dueWorkoutReminders(
  Iterable<PlannedWorkout> workouts, {
  required DateTime now,
  required int leadMinutes,
  int limit = kMaxWorkoutReminders,
}) {
  final due =
      [
          for (final w in workouts)
            if (!w.isRest && !w.isCompleted)
              DueWorkout(
                w,
                w.scheduledAt.subtract(Duration(minutes: leadMinutes)),
              ),
        ].where((d) => d.at.isAfter(now)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  return due.take(limit).toList();
}

/// This week's distance just reached [goalMeters] (it was below before).
bool reachedWeeklyGoal({
  required double beforeMeters,
  required double afterMeters,
  required double goalMeters,
}) => beforeMeters < goalMeters && afterMeters >= goalMeters;

/// The next 06:00 (today when it is still before then).
DateTime nextMorning(DateTime now, {int hour = 6}) {
  final today = DateTime(now.year, now.month, now.day, hour);
  return now.isBefore(today)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour);
}
