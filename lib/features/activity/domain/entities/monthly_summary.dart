import 'activity.dart';

/// Activities of one calendar month with their totals (history sections).
class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.activities,
    required this.distanceMeters,
    required this.movingTime,
    required this.elevationGainMeters,
  });

  /// First day of the month.
  final DateTime month;

  /// Newest first.
  final List<ActivitySummary> activities;
  final double distanceMeters;
  final Duration movingTime;
  final double elevationGainMeters;

  int get count => activities.length;

  /// Groups [activities] (any order) into months, newest month first.
  static List<MonthlySummary> group(Iterable<ActivitySummary> activities) {
    final byMonth = <DateTime, List<ActivitySummary>>{};
    for (final a in activities) {
      final key = DateTime(a.startedAt.year, a.startedAt.month);
      (byMonth[key] ??= []).add(a);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final m in months)
        () {
          final list = byMonth[m]!
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
          return MonthlySummary(
            month: m,
            activities: list,
            distanceMeters: list.fold(0, (s, a) => s + a.distanceMeters),
            movingTime: list.fold(Duration.zero, (s, a) => s + a.movingTime),
            elevationGainMeters: list.fold(
              0,
              (s, a) => s + a.elevationGainMeters,
            ),
          );
        }(),
    ];
  }
}
