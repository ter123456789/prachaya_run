import 'activity.dart';

/// How hard an activity was compared with the user's usual speed for the
/// same sport.
enum Effort { easy, steady, tempo }

/// Derived facts for the detail and dashboard cards. Pure, from the track
/// and the user's other activities.
class ActivityInsights {
  ActivityInsights._({
    required this.totalTime,
    required this.activeRate,
    required this.netElevationMeters,
    required this.averageAccuracyMeters,
    required this.distanceVsAveragePercent,
    required this.effort,
  });

  factory ActivityInsights.of(
    Activity activity, {
    Iterable<ActivitySummary> history = const [],
  }) {
    final total = activity.endedAt.difference(activity.startedAt);
    final points = activity.segments.expand((s) => s).toList();

    final altitudes = points
        .map((p) => p.altitudeMeters)
        .whereType<double>()
        .toList();
    final net = altitudes.length < 2 ? 0.0 : altitudes.last - altitudes.first;

    final accuracies = points
        .map((p) => p.accuracyMeters)
        .whereType<double>()
        .toList();
    final accuracy = accuracies.isEmpty
        ? null
        : accuracies.reduce((a, b) => a + b) / accuracies.length;

    final others = history
        .where((h) => h.type == activity.type && h.id != activity.id)
        .toList();
    double? vsAverage;
    Effort? effort;
    if (others.isNotEmpty) {
      final avgDistance =
          others.fold<double>(0, (s, h) => s + h.distanceMeters) /
          others.length;
      if (avgDistance > 0) {
        vsAverage = (activity.distanceMeters / avgDistance - 1) * 100;
      }
      final distance = others.fold<double>(0, (s, h) => s + h.distanceMeters);
      final seconds = others.fold<int>(0, (s, h) => s + h.movingTime.inSeconds);
      final usual = seconds <= 0 ? 0.0 : distance / seconds;
      final speed = activity.summary.averageSpeedMps;
      if (usual > 0 && speed > 0) {
        effort = speed < usual * 0.95
            ? Effort.easy
            : speed > usual * 1.05
            ? Effort.tempo
            : Effort.steady;
      }
    }

    return ActivityInsights._(
      totalTime: total,
      activeRate: total.inMilliseconds <= 0
          ? 1
          : (activity.movingTime.inMilliseconds / total.inMilliseconds).clamp(
              0.0,
              1.0,
            ),
      netElevationMeters: net,
      averageAccuracyMeters: accuracy,
      distanceVsAveragePercent: vsAverage,
      effort: effort,
    );
  }

  /// Start to finish, pauses included.
  final Duration totalTime;

  /// Moving time / total time, 0–1.
  final double activeRate;

  /// Last altitude minus first.
  final double netElevationMeters;

  /// Mean reported GPS accuracy of the stored fixes, if any were reported.
  final double? averageAccuracyMeters;

  /// This distance vs. the mean of the user's other activities of the same
  /// type, in percent; null without history.
  final double? distanceVsAveragePercent;

  /// Null without history to compare with.
  final Effort? effort;
}
