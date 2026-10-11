import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_insights.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/monthly_summary.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/entities/weather_report.dart';
import 'package:prachaya_run/features/activity/domain/entities/weekly_stats.dart';
import 'package:prachaya_run/features/activity/domain/services/calories.dart';

import '../../../helpers/fakes.dart';

ActivitySummary _summary(
  String id,
  DateTime at, {
  double km = 5,
  int minutes = 30,
  ActivityType type = ActivityType.run,
}) => ActivitySummary(
  id: id,
  type: type,
  title: id,
  startedAt: at,
  movingTime: Duration(minutes: minutes),
  distanceMeters: km * 1000,
  elevationGainMeters: 20,
);

void main() {
  group('WeeklyStats extras', () {
    test('ISO week numbers across year boundaries', () {
      WeeklyStats week(DateTime d) => WeeklyStats.from(const [], d);
      expect(week(DateTime(2026, 10, 11)).weekNumber, 41);
      expect(week(DateTime(2026, 1, 1)).weekNumber, 1); // Thu
      expect(week(DateTime(2027, 1, 1)).weekNumber, 53); // Fri → 2026-W53
      expect(week(DateTime(2027, 1, 4)).weekNumber, 1);
    });

    test('today distance and average grade', () {
      final now = DateTime(2026, 10, 9, 18);
      final stats = WeeklyStats.from([
        _summary('a', DateTime(2026, 10, 9, 6), km: 3),
        _summary('b', DateTime(2026, 10, 8, 6), km: 2),
      ], now);
      expect(stats.todayDistanceMeters, 3000);
      expect(stats.averageGradePercent, closeTo(40 / 5000 * 100, 1e-9));
    });
  });

  test('calorie estimates are plausible and scale with weight', () {
    final run = estimateCalories(
      type: ActivityType.run,
      distanceMeters: 10000,
      movingTime: const Duration(minutes: 55),
      weightKg: 70,
    );
    expect(run, closeTo(725, 5));
    final light = estimateCalories(
      type: ActivityType.run,
      distanceMeters: 10000,
      movingTime: const Duration(minutes: 55),
      weightKg: 50,
    );
    expect(light, lessThan(run));
    final ride = estimateCalories(
      type: ActivityType.ride,
      distanceMeters: 30000,
      movingTime: const Duration(hours: 1),
    );
    expect(ride, closeTo(12 * kDefaultWeightKg, 1)); // 30 km/h → MET 12
    expect(
      estimateCalories(
        type: ActivityType.hike,
        distanceMeters: 0,
        movingTime: Duration.zero,
      ),
      0,
    );
  });

  test('monthly summaries group and total, newest first', () {
    final months = MonthlySummary.group([
      _summary('sep', DateTime(2026, 9, 30, 7), km: 4),
      _summary('oct1', DateTime(2026, 10, 1, 7), km: 5),
      _summary('oct2', DateTime(2026, 10, 9, 7), km: 6, minutes: 40),
    ]);
    expect(months.map((m) => m.month), [DateTime(2026, 10), DateTime(2026, 9)]);
    expect(months.first.count, 2);
    expect(months.first.distanceMeters, 11000);
    expect(months.first.movingTime, const Duration(minutes: 70));
    expect(months.first.activities.first.id, 'oct2');
  });

  group('ActivityInsights', () {
    final activity = Activity(
      id: 'x',
      type: ActivityType.run,
      title: 't',
      startedAt: t0,
      endedAt: t0.add(const Duration(minutes: 40)),
      movingTime: const Duration(minutes: 30),
      segments: [
        [
          TrackPoint(
            latitude: 13.7,
            longitude: 100.5,
            timestamp: t0,
            altitudeMeters: 10,
            accuracyMeters: 4,
          ),
          TrackPoint(
            latitude: 13.745, // ≈ 5 km north
            longitude: 100.5,
            timestamp: t0.add(const Duration(minutes: 30)),
            altitudeMeters: 25,
            accuracyMeters: 8,
          ),
        ],
      ],
    );

    test('time, net elevation and GPS accuracy', () {
      final i = ActivityInsights.of(activity);
      expect(i.totalTime, const Duration(minutes: 40));
      expect(i.activeRate, closeTo(0.75, 1e-9));
      expect(i.netElevationMeters, 15);
      expect(i.averageAccuracyMeters, 6);
      expect(i.distanceVsAveragePercent, isNull);
      expect(i.effort, isNull);
    });

    test('compares with the same sport only', () {
      final i = ActivityInsights.of(
        activity,
        history: [
          // 4 km in 30 min: slower than this 5 km in 30 min → tempo.
          _summary('a', t0, km: 4),
          _summary('b', t0, km: 4),
          _summary('ride', t0, km: 40, type: ActivityType.ride),
          _summary('x', t0, km: 99), // itself: ignored
        ],
      );
      expect(i.distanceVsAveragePercent, closeTo(25, 0.5));
      expect(i.effort, Effort.tempo);
    });
  });

  test('run advice from weather', () {
    WeatherReport w(
      double t, {
      WeatherKind k = WeatherKind.clear,
      double wind = 5,
    }) => WeatherReport(temperatureC: t, windKmh: wind, kind: k, isNight: true);
    expect(adviseRun(w(26)), RunAdvice.great);
    expect(adviseRun(w(30)), RunAdvice.hot);
    expect(adviseRun(w(35)), RunAdvice.veryHot);
    expect(adviseRun(w(26, k: WeatherKind.rain)), RunAdvice.wet);
    expect(adviseRun(w(26, wind: 40)), RunAdvice.windy);
    expect(WeatherReport.kindFromWmo(61), WeatherKind.rain);
    expect(WeatherReport.kindFromWmo(3), WeatherKind.cloudy);
  });
}
