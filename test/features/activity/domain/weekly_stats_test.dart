import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/weekly_stats.dart';

ActivitySummary _run(DateTime at, double km) => ActivitySummary(
  id: at.toIso8601String(),
  type: ActivityType.run,
  title: 'run',
  startedAt: at,
  movingTime: const Duration(minutes: 30),
  distanceMeters: km * 1000,
  elevationGainMeters: 10,
);

void main() {
  // Thursday 9 Oct 2026 → week starts Monday 5 Oct.
  final now = DateTime(2026, 10, 9, 18);

  test('sums only Monday-to-Sunday of the current week', () {
    final stats = WeeklyStats.from([
      _run(DateTime(2026, 10, 5, 0, 0), 5), // Monday 00:00 → in
      _run(DateTime(2026, 10, 9, 6), 3), // today → in
      _run(DateTime(2026, 10, 4, 23, 59), 7), // previous Sunday → prev week
      _run(DateTime(2026, 9, 27, 7), 100), // two weeks ago → ignored
    ], now);

    expect(stats.weekStart, DateTime(2026, 10, 5));
    expect(stats.activityCount, 2);
    expect(stats.distanceMeters, 8000);
    expect(stats.movingTime, const Duration(hours: 1));
    expect(stats.previousWeekDistanceMeters, 7000);
    expect(stats.distanceChangeMeters, 1000);
  });

  test('progress is clamped to 0–1', () {
    final stats = WeeklyStats.from([_run(now, 30)], now);
    expect(stats.progressToward(20000), 1);
    expect(stats.progressToward(60000), 0.5);
    expect(WeeklyStats.from([], now).progressToward(20000), 0);
  });
}
