import 'activity.dart';

/// Totals for the calendar week (Monday start) containing a given day,
/// compared with the week before.
class WeeklyStats {
  const WeeklyStats({
    required this.weekStart,
    required this.distanceMeters,
    required this.movingTime,
    required this.elevationGainMeters,
    required this.activityCount,
    required this.previousWeekDistanceMeters,
    this.todayDistanceMeters = 0,
  });

  factory WeeklyStats.from(Iterable<ActivitySummary> activities, DateTime now) {
    // Calendar arithmetic (not Duration) so DST shifts can't move the boundary.
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final nextWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final previousWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );

    var distance = 0.0;
    var elevation = 0.0;
    var time = Duration.zero;
    var count = 0;
    var previousDistance = 0.0;
    var today = 0.0;
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    for (final a in activities) {
      final t = a.startedAt;
      if (!t.isBefore(todayStart) && t.isBefore(tomorrow)) {
        today += a.distanceMeters;
      }
      if (!t.isBefore(weekStart) && t.isBefore(nextWeekStart)) {
        distance += a.distanceMeters;
        elevation += a.elevationGainMeters;
        time += a.movingTime;
        count++;
      } else if (!t.isBefore(previousWeekStart) && t.isBefore(weekStart)) {
        previousDistance += a.distanceMeters;
      }
    }
    return WeeklyStats(
      weekStart: weekStart,
      distanceMeters: distance,
      movingTime: time,
      elevationGainMeters: elevation,
      activityCount: count,
      previousWeekDistanceMeters: previousDistance,
      todayDistanceMeters: today,
    );
  }

  final DateTime weekStart;
  final double distanceMeters;
  final Duration movingTime;
  final double elevationGainMeters;
  final int activityCount;
  final double previousWeekDistanceMeters;
  final double todayDistanceMeters;

  /// ISO 8601 week number (weeks start Monday; week 1 holds 4 January).
  int get weekNumber {
    // The Thursday of this week decides which year the week belongs to.
    final thursday = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 3,
    );
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekStart = DateTime(
      firstThursday.year,
      1,
      4 - (firstThursday.weekday - 1),
    );
    final days = DateTime.utc(weekStart.year, weekStart.month, weekStart.day)
        .difference(
          DateTime.utc(
            firstWeekStart.year,
            firstWeekStart.month,
            firstWeekStart.day,
          ),
        )
        .inDays;
    return days ~/ 7 + 1;
  }

  /// Climb per distance this week, in percent (0 when nothing recorded).
  double get averageGradePercent =>
      distanceMeters <= 0 ? 0 : elevationGainMeters / distanceMeters * 100;

  /// 0–1 share of [goalMeters] covered this week.
  double progressToward(double goalMeters) =>
      goalMeters <= 0 ? 0 : (distanceMeters / goalMeters).clamp(0.0, 1.0);

  double get distanceChangeMeters =>
      distanceMeters - previousWeekDistanceMeters;
}
