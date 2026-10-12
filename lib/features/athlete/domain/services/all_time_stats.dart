import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/activity_type.dart';

/// Lifetime totals over every activity on the device.
class AllTimeStats {
  const AllTimeStats({
    required this.distanceMeters,
    required this.movingTime,
    required this.count,
    required this.runCount,
    required this.runDistanceMeters,
    required this.runMovingTime,
    this.firstYear,
  });

  factory AllTimeStats.from(Iterable<ActivitySummary> activities) {
    var distance = 0.0;
    var time = Duration.zero;
    var count = 0;
    var runs = 0;
    var runDistance = 0.0;
    var runTime = Duration.zero;
    int? firstYear;
    for (final a in activities) {
      distance += a.distanceMeters;
      time += a.movingTime;
      count++;
      if (a.type == ActivityType.run) {
        runs++;
        runDistance += a.distanceMeters;
        runTime += a.movingTime;
      }
      final year = a.startedAt.year;
      if (firstYear == null || year < firstYear) firstYear = year;
    }
    return AllTimeStats(
      distanceMeters: distance,
      movingTime: time,
      count: count,
      runCount: runs,
      runDistanceMeters: runDistance,
      runMovingTime: runTime,
      firstYear: firstYear,
    );
  }

  final double distanceMeters;
  final Duration movingTime;
  final int count;
  final int runCount;
  final double runDistanceMeters;
  final Duration runMovingTime;

  /// Year of the oldest activity; null with none.
  final int? firstYear;

  /// Share of activities that are runs, 0–1.
  double get runShare => count == 0 ? 0 : runCount / count;

  /// Average running speed over all runs (distance ÷ moving time), for the
  /// lifetime pace. 0 without runs.
  double get runAverageSpeedMps {
    final s = runMovingTime.inMilliseconds / 1000;
    return s <= 0 ? 0 : runDistanceMeters / s;
  }

  @override
  bool operator ==(Object other) =>
      other is AllTimeStats &&
      other.distanceMeters == distanceMeters &&
      other.movingTime == movingTime &&
      other.count == count &&
      other.runCount == runCount &&
      other.firstYear == firstYear;

  @override
  int get hashCode =>
      Object.hash(distanceMeters, movingTime, count, runCount, firstYear);
}
