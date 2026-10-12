import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/activity_type.dart';
import '../entities/planned_workout.dart';

/// Starting values for a new session of each type; the user edits them.
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.title,
    required this.distanceMeters,
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
  });

  final String title;
  final double distanceMeters;
  final int? paceMinSecPerKm;
  final int? paceMaxSecPerKm;
}

WorkoutTemplate templateFor(WorkoutType type) => switch (type) {
  WorkoutType.easy => const WorkoutTemplate(
    title: 'Easy Run วิ่งสบายฟื้นฟู',
    distanceMeters: 5000,
    paceMinSecPerKm: 390,
    paceMaxSecPerKm: 420,
  ),
  WorkoutType.tempo => const WorkoutTemplate(
    title: 'Tempo Run พัฒนาความเร็ว',
    distanceMeters: 7000,
    paceMinSecPerKm: 315,
    paceMaxSecPerKm: 330,
  ),
  WorkoutType.interval => const WorkoutTemplate(
    title: 'Interval วิ่งสลับความเร็ว',
    distanceMeters: 6000,
    paceMinSecPerKm: 285,
    paceMaxSecPerKm: 300,
  ),
  WorkoutType.long => const WorkoutTemplate(
    title: 'Long Run วิ่งยาวฝึกความอึด',
    distanceMeters: 15000,
    paceMinSecPerKm: 360,
    paceMaxSecPerKm: 375,
  ),
  WorkoutType.rest => const WorkoutTemplate(
    title: 'วันพักกล้ามเนื้อ (Rest Day)',
    distanceMeters: 0,
  ),
};

/// Heart-rate zones each type aims for (1–5).
(int, int)? targetZones(WorkoutType type) => switch (type) {
  WorkoutType.easy => (2, 2),
  WorkoutType.tempo => (3, 4),
  WorkoutType.interval => (4, 5),
  WorkoutType.long => (2, 3),
  WorkoutType.rest => null,
};

enum PhaseKind { warmUp, main, coolDown }

class WorkoutPhase {
  const WorkoutPhase({
    required this.kind,
    required this.distanceMeters,
    required this.paceSecPerKm,
    required this.zoneLow,
    required this.zoneHigh,
  });

  final PhaseKind kind;
  final double distanceMeters;

  /// The pace to hold (the fast end of the range for the main set).
  final int paceSecPerKm;
  final int zoneLow;
  final int zoneHigh;

  @override
  bool operator ==(Object other) =>
      other is WorkoutPhase &&
      other.kind == kind &&
      other.distanceMeters == distanceMeters &&
      other.paceSecPerKm == paceSecPerKm &&
      other.zoneLow == zoneLow &&
      other.zoneHigh == zoneHigh;

  @override
  int get hashCode =>
      Object.hash(kind, distanceMeters, paceSecPerKm, zoneLow, zoneHigh);

  @override
  String toString() =>
      'WorkoutPhase($kind, ${distanceMeters}m @ $paceSecPerKm, '
      'Z$zoneLow-$zoneHigh)';
}

/// Tempo and interval sessions of at least 3 km get a 1 km warm-up at the
/// slow end of the range + 60 s (zones 1–2) and a 1 km cool-down at the
/// slow end + 90 s (zone 1) around the main set. Other sessions are one
/// steady block. Rest days have none.
List<WorkoutPhase> workoutPhases(PlannedWorkout w) {
  final min = w.paceMinSecPerKm;
  final max = w.paceMaxSecPerKm;
  final zones = targetZones(w.type);
  if (w.isRest || min == null || max == null || zones == null) return const [];
  final structured =
      (w.type == WorkoutType.tempo || w.type == WorkoutType.interval) &&
      w.distanceMeters >= 3000;
  if (!structured) {
    return [
      WorkoutPhase(
        kind: PhaseKind.main,
        distanceMeters: w.distanceMeters,
        paceSecPerKm: min,
        zoneLow: zones.$1,
        zoneHigh: zones.$2,
      ),
    ];
  }
  return [
    WorkoutPhase(
      kind: PhaseKind.warmUp,
      distanceMeters: 1000,
      paceSecPerKm: max + 60,
      zoneLow: 1,
      zoneHigh: 2,
    ),
    WorkoutPhase(
      kind: PhaseKind.main,
      distanceMeters: w.distanceMeters - 2000,
      paceSecPerKm: min,
      zoneLow: zones.$2,
      zoneHigh: zones.$2,
    ),
    WorkoutPhase(
      kind: PhaseKind.coolDown,
      distanceMeters: 1000,
      paceSecPerKm: max + 90,
      zoneLow: 1,
      zoneHigh: 1,
    ),
  ];
}

/// Distance × the middle of the target pace range. Null for rest days.
Duration? estimatedDuration(PlannedWorkout w) {
  final min = w.paceMinSecPerKm;
  final max = w.paceMaxSecPerKm;
  if (w.isRest || min == null || max == null) return null;
  final seconds = w.distanceMeters / 1000 * (min + max) / 2;
  return Duration(seconds: seconds.round());
}

/// Same limits as the server (docs/api.md, Planned workouts).
bool isValidWorkout(PlannedWorkout w) {
  final title = w.title.trim();
  if (title.isEmpty || title.length > 80) return false;
  if ((w.location?.length ?? 0) > 80) return false;
  if (w.distanceMeters < 0 || w.distanceMeters > 100000) return false;
  final min = w.paceMinSecPerKm;
  final max = w.paceMaxSecPerKm;
  if (w.isRest) return w.distanceMeters == 0 && min == null && max == null;
  if (w.distanceMeters <= 0) return false;
  // Both paces or neither (no pace target).
  if (min == null || max == null) return min == null && max == null;
  return min >= 120 && max <= 1200 && min <= max;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

bool isSameDay(DateTime a, DateTime b) => _day(a) == _day(b);

/// One day of the week strip.
class TrainingDay {
  const TrainingDay(this.date, this.workouts);

  final DateTime date;
  final List<PlannedWorkout> workouts;

  bool get isRestDay => workouts.isNotEmpty && workouts.every((w) => w.isRest);
}

/// The calendar week (Monday start) around a day: its sessions and how much
/// of them is done. A session counts as done only while its linked
/// activity still exists.
class TrainingWeek {
  const TrainingWeek({
    required this.days,
    required this.plannedSessions,
    required this.completedSessions,
    required this.plannedMeters,
    required this.completedMeters,
  });

  factory TrainingWeek.from(
    Iterable<PlannedWorkout> workouts,
    Iterable<ActivitySummary> activities,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final byId = {for (final a in activities) a.id: a};
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    var planned = 0;
    var done = 0;
    var plannedMeters = 0.0;
    var doneMeters = 0.0;
    final perDay = <TrainingDay>[];
    for (final day in days) {
      final list = workouts.where((w) => isSameDay(w.scheduledAt, day)).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      perDay.add(TrainingDay(day, list));
      for (final w in list) {
        if (w.isRest) continue;
        planned++;
        plannedMeters += w.distanceMeters;
        final activity = byId[w.completedActivityId];
        if (activity != null) {
          done++;
          doneMeters += activity.distanceMeters;
        }
      }
    }
    return TrainingWeek(
      days: perDay,
      plannedSessions: planned,
      completedSessions: done,
      plannedMeters: plannedMeters,
      completedMeters: doneMeters,
    );
  }

  final List<TrainingDay> days;
  final int plannedSessions;
  final int completedSessions;
  final double plannedMeters;
  final double completedMeters;

  DateTime get start => days.first.date;
  DateTime get end => days.last.date;

  /// ISO 8601 week number (weeks start Monday; week 1 holds 4 January).
  int get weekNumber {
    // UTC so a DST shift cannot shorten a day.
    final thursday = DateTime.utc(start.year, start.month, start.day + 3);
    final dayOfYear = thursday.difference(DateTime.utc(thursday.year)).inDays;
    return dayOfYear ~/ 7 + 1;
  }

  /// Distance done ÷ distance planned, 0–1.
  double get progress => plannedMeters <= 0
      ? 0
      : (completedMeters / plannedMeters).clamp(0.0, 1.0);
}

/// Today's session to show first: the earliest one not done yet, else the
/// first one of the day.
PlannedWorkout? todaysWorkout(Iterable<PlannedWorkout> workouts, DateTime now) {
  final today = workouts.where((w) => isSameDay(w.scheduledAt, now)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (today.isEmpty) return null;
  return today.firstWhere((w) => !w.isCompleted, orElse: () => today.first);
}

/// Sessions after today, soonest first.
List<PlannedWorkout> upcomingWorkouts(
  Iterable<PlannedWorkout> workouts,
  DateTime now, {
  int limit = 3,
}) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final list = workouts.where((w) => !w.scheduledAt.isBefore(tomorrow)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return list.take(limit).toList();
}

/// The session a just-saved run fulfils: an open, non-rest session on the
/// same day, the one scheduled closest to the run's start.
PlannedWorkout? workoutFulfilledBy(
  ActivitySummary activity,
  Iterable<PlannedWorkout> workouts,
) {
  if (activity.type != ActivityType.run) return null;
  PlannedWorkout? best;
  Duration? bestGap;
  for (final w in workouts) {
    if (w.isRest || w.isCompleted) continue;
    if (!isSameDay(w.scheduledAt, activity.startedAt)) continue;
    final gap = w.scheduledAt.difference(activity.startedAt).abs();
    if (bestGap == null || gap < bestGap) {
      best = w;
      bestGap = gap;
    }
  }
  return best;
}
