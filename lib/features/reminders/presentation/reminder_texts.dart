import '../../../core/formatters.dart';
import '../../activity/domain/entities/weather_report.dart';
import '../../activity/domain/entities/weekly_stats.dart';
import '../../activity/presentation/activity_labels.dart';
import '../../athlete/presentation/units.dart';
import '../../training/presentation/training_labels.dart';
import '../domain/entities/reminder.dart';
import '../domain/services/reminder_plan.dart';

/// Thai notification texts, in the app's distance unit.
abstract final class ReminderTexts {
  /// `อีก 30 นาที: Tempo Run` / `8 กม. • เพซ 5'10"-5'30" /กม. • สวนลุมพินี`
  static Reminder workout(UnitFormat units, DueWorkout due, int lead) {
    final w = due.workout;
    final pace = w.paceMinSecPerKm == null
        ? null
        : 'เพซ ${paceRange(units, w)} ${units.paceUnit}';
    return Reminder(
      id: workoutReminderId(w.id),
      kind: ReminderKind.workout,
      at: due.at,
      title: 'อีก ${_lead(lead)}: ${w.title}',
      body: [
        '${planDistance(units, w.distanceMeters)} ${units.distanceUnit}',
        ?pace,
        ?w.location,
        'เริ่ม ${formatClock(w.scheduledAt)} น.',
      ].join(' • '),
      target: ScheduleTarget(w.scheduledAt),
    );
  }

  static String _lead(int minutes) =>
      minutes % 60 == 0 ? '${minutes ~/ 60} ชั่วโมง' : '$minutes นาที';

  /// `บรรลุเป้าหมายรายสัปดาห์!` / `วิ่งสะสมครบ 20.00 กม. แล้ว ...`
  static Reminder weeklyGoal(
    UnitFormat units,
    WeeklyStats week,
    DateTime now,
  ) => Reminder(
    id: kWeeklyGoalReminderId,
    kind: ReminderKind.weeklyGoal,
    at: now,
    title: 'บรรลุเป้าหมายรายสัปดาห์!',
    body:
        'สะสมครบ ${units.distance(kWeeklyGoalMeters)} '
        '${units.distanceUnit} แล้ว '
        '(${units.distance(week.distanceMeters)} ${units.distanceUnit} '
        'จาก ${week.activityCount} ครั้ง) รักษาวินัยนี้ไว้',
    target: const HomeTarget(),
  );

  /// `อากาศสำหรับวิ่ง 06:00 น.` / `27°C แดดดี • ลม 8 กม./ชม. • อากาศดี เหมาะออกไปวิ่ง`
  static Reminder weather(UnitFormat units, WeatherReport w, DateTime at) =>
      Reminder(
        id: kWeatherReminderId,
        kind: ReminderKind.weather,
        at: at,
        title: 'อากาศสำหรับวิ่ง ${formatClock(at)} น.',
        body: [
          '${w.temperatureLabel} ${w.description}',
          'ลม ${units.windFromKmh(w.windKmh)}',
          adviseRun(w).headline,
        ].join(' • '),
        target: const HomeTarget(),
      );
}
