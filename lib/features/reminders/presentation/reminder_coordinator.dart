import '../../activity/domain/entities/weekly_stats.dart';
import '../../activity/domain/services/weather_service.dart';
import '../../athlete/presentation/units.dart';
import '../../training/domain/entities/planned_workout.dart';
import '../domain/entities/reminder.dart';
import '../domain/entities/reminder_settings.dart';
import '../domain/repositories/reminder_scheduler.dart';
import '../domain/services/reminder_plan.dart';
import 'reminder_texts.dart';

/// Keeps the device's pending reminders in step with the current owner's
/// plans and the settings. Called by app-level listeners whenever plans,
/// settings, the unit or the signed-in account change.
class ReminderCoordinator {
  ReminderCoordinator(
    this._scheduler, {
    WeatherService? weather,
    DateTime Function() clock = DateTime.now,
  }) : _weather = weather,
       _clock = clock;

  final ReminderScheduler _scheduler;
  final WeatherService? _weather;
  final DateTime Function() _clock;

  /// Every session still ahead gets one reminder; the rest are cancelled
  /// (deleted, done, moved, another account's).
  Future<void> planWorkouts(
    List<PlannedWorkout> workouts,
    ReminderSettings settings,
    UnitFormat units,
  ) {
    final lead = settings.workoutLeadMinutes;
    final reminders = lead == null
        ? const <Reminder>[]
        : [
            for (final due in dueWorkoutReminders(
              workouts,
              now: _clock(),
              leadMinutes: lead,
            ))
              ReminderTexts.workout(units, due, lead),
          ];
    return _scheduler.replace(ReminderKind.workout, reminders);
  }

  /// Shown at once when this week's distance just passed the goal.
  Future<void> weekChanged(
    WeeklyStats? before,
    WeeklyStats after,
    ReminderSettings settings,
    UnitFormat units,
  ) async {
    if (!settings.weeklyGoal || before == null) return;
    if (before.weekStart != after.weekStart) return;
    if (!reachedWeeklyGoal(
      beforeMeters: before.distanceMeters,
      afterMeters: after.distanceMeters,
      goalMeters: kWeeklyGoalMeters,
    )) {
      return;
    }
    await _scheduler.showNow(ReminderTexts.weeklyGoal(units, after, _clock()));
  }

  /// Tomorrow's (or this morning's) 06:00 forecast where the runner last
  /// started; cancelled when off or without a place or a forecast.
  Future<void> planWeather(
    ({double lat, double lng})? place,
    ReminderSettings settings,
    UnitFormat units,
  ) async {
    final weather = _weather;
    if (!settings.morningWeather || place == null || weather == null) {
      await _scheduler.replace(ReminderKind.weather, const []);
      return;
    }
    final at = nextMorning(_clock());
    final report = await weather.forecast(
      lat: place.lat,
      lng: place.lng,
      time: at,
    );
    await _scheduler.replace(ReminderKind.weather, [
      if (report != null) ReminderTexts.weather(units, report, at),
    ]);
  }
}
