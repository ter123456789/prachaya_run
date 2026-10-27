import '../entities/activity.dart';
import '../entities/activity_origin.dart';
import '../entities/activity_type.dart';
import '../entities/heart_rate.dart';
import '../entities/imported_workout.dart';
import '../entities/track_point.dart';
import '../repositories/activity_repository.dart';
import '../repositories/health_import_store.dart';
import '../services/health_source.dart';
import '../services/uuid.dart';
import 'save_activity.dart';

class ImportResult {
  const ImportResult({this.imported = 0, this.heartRateAdded = 0});

  static const none = ImportResult();

  /// New activities.
  final int imported;

  /// Existing activities that got heart rate from the health store.
  final int heartRateAdded;

  bool get changed => imported > 0 || heartRateAdded > 0;
}

/// Brings workouts recorded by watch apps in from Apple Health / Health
/// Connect (docs/backlog/health-import.md):
/// - each workout gets a stable id, so a second run never duplicates it;
/// - one that overlaps an activity already here by ≥ 50 % is not added;
///   its heart rate goes to that activity instead, if it has none;
/// - activities recorded on the phone in the last [backfillWindow] without
///   heart rate get the health store's heart rate (a watch worn while the
///   phone recorded).
/// New activities count toward the primary shoe and tick off plans, like a
/// recording ([defaultShoe], [onSaved]).
class ImportActivities {
  ImportActivities(
    this._source,
    this._repository,
    this._store, {
    required this.titleFor,
    DefaultShoe? defaultShoe,
    List<ActivitySavedHook> onSaved = const [],
    DateTime Function() clock = DateTime.now,
    this.lookBack = const Duration(days: 7),
    this.backfillWindow = const Duration(hours: 48),
  }) : _defaultShoe = defaultShoe,
       _onSaved = onSaved,
       _clock = clock;

  final HealthSource _source;
  final ActivityRepository _repository;
  final HealthImportStore _store;

  /// The default title, e.g. "วิ่งตอนเช้า" (labels live in presentation).
  final String Function(ActivityType type, DateTime start) titleFor;
  final DefaultShoe? _defaultShoe;
  final List<ActivitySavedHook> _onSaved;
  final DateTime Function() _clock;

  /// Watch apps sync late: each run looks this far behind the last one.
  final Duration lookBack;
  final Duration backfillWindow;

  /// A gap this long in a route starts a new segment (a pause).
  static const routeGap = Duration(seconds: 60);

  /// Overlap (of the shorter one) that makes two activities the same.
  static const sameWorkout = 0.5;

  Future<ImportResult> call() async {
    final settings = await _store.load();
    if (!settings.enabled) return ImportResult.none;
    final now = _clock();
    final since = settings.since ?? now;
    final last = settings.lastImportAt?.subtract(lookBack);
    final from = last != null && last.isAfter(since) ? last : since;

    final workouts = await _source.workouts(from: from, to: now)
      ..sort((a, b) => a.start.compareTo(b.start));
    final existing = await _repository.getAll();
    final ids = {for (final s in existing) s.id};
    final seen = {
      for (final e in settings.seen.entries)
        if (!e.value.isBefore(from.subtract(const Duration(days: 1))))
          e.key: e.value,
    };

    var imported = 0;
    var merged = 0;
    for (final w in workouts) {
      final type = _typeOf(w.kind, includeWalks: settings.includeWalks);
      if (type == null) continue;
      final id = uuidV5('${w.source}:${w.externalId}');
      if (seen.containsKey(id) || ids.contains(id)) {
        seen[id] = w.start;
        continue;
      }
      seen[id] = w.start;
      final detail = await _source.detail(w);
      final twin = _overlapping(existing, w.start, w.end);
      if (twin != null) {
        if (await _addHeartRate(twin.id, detail.heartRate)) merged++;
        continue;
      }
      var activity = Activity(
        id: id,
        type: type,
        title: titleFor(type, w.start),
        startedAt: w.start,
        endedAt: w.end,
        movingTime: w.activeTime ?? w.end.difference(w.start),
        segments: splitAtGaps(detail.route, routeGap),
        heartRate: detail.heartRate.isEmpty
            ? null
            : HeartRateTrack(
                source: HeartRateSource.health,
                samples: detail.heartRate,
              ),
        origin: ActivityOrigin(OriginKind.health, app: w.app, device: w.device),
        reportedDistanceMeters: w.distanceMeters,
        reportedElevationGainMeters: w.elevationGainMeters,
      );
      final shoe = await _defaultShoe?.call(type);
      if (shoe != null) activity = activity.withShoe(shoe);
      await _repository.save(activity);
      for (final hook in _onSaved) {
        await hook(activity);
      }
      ids.add(id);
      imported++;
    }

    merged += await _backfillHeartRate(existing, now);

    await _store.save(
      settings.copyWith(lastImportAt: now, lastImported: imported, seen: seen),
    );
    return ImportResult(imported: imported, heartRateAdded: merged);
  }

  /// Phone recordings of the last [backfillWindow] still without heart rate.
  Future<int> _backfillHeartRate(
    List<ActivitySummary> existing,
    DateTime now,
  ) async {
    var added = 0;
    for (final s in existing) {
      if (!s.origin.isPhone || now.difference(s.end) > backfillWindow) {
        continue;
      }
      final activity = await _repository.getById(s.id);
      if (activity == null || activity.heartRate != null) continue;
      final samples = await _source.heartRate(
        from: activity.startedAt,
        to: activity.endedAt,
      );
      // Only while moving: a sample in a pause is not part of the run.
      final moving = [
        for (final sample in samples)
          if (activity.segments.any(
            (seg) =>
                seg.isNotEmpty &&
                !sample.timestamp.isBefore(seg.first.timestamp) &&
                !sample.timestamp.isAfter(seg.last.timestamp),
          ))
            sample,
      ];
      if (moving.length < 2) continue;
      await _repository.save(
        activity.withHeartRate(
          HeartRateTrack(source: HeartRateSource.health, samples: moving),
        ),
      );
      added++;
    }
    return added;
  }

  Future<bool> _addHeartRate(String id, List<HeartRateSample> samples) async {
    if (samples.isEmpty) return false;
    final activity = await _repository.getById(id);
    if (activity == null || activity.heartRate != null) return false;
    await _repository.save(
      activity.withHeartRate(
        HeartRateTrack(source: HeartRateSource.health, samples: samples),
      ),
    );
    return true;
  }

  static ActivitySummary? _overlapping(
    List<ActivitySummary> existing,
    DateTime start,
    DateTime end,
  ) {
    for (final s in existing) {
      if (overlapShare(s.startedAt, s.end, start, end) >= sameWorkout) {
        return s;
      }
    }
    return null;
  }

  static ActivityType? _typeOf(
    WorkoutKind kind, {
    required bool includeWalks,
  }) => switch (kind) {
    WorkoutKind.run => ActivityType.run,
    WorkoutKind.ride => ActivityType.ride,
    WorkoutKind.hike => ActivityType.hike,
    WorkoutKind.walk => includeWalks ? ActivityType.hike : null,
  };
}

/// Overlap of two time spans as a share of the shorter one (0–1).
double overlapShare(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  final overlap = end.difference(start).inMilliseconds;
  if (overlap <= 0) return 0;
  final a = aEnd.difference(aStart).inMilliseconds;
  final b = bEnd.difference(bStart).inMilliseconds;
  final shorter = a < b ? a : b;
  return shorter <= 0 ? 0 : overlap / shorter;
}

/// A route as segments, a new one after each gap longer than [gap].
List<List<TrackPoint>> splitAtGaps(List<TrackPoint> route, Duration gap) {
  final segments = <List<TrackPoint>>[];
  for (final p in route) {
    if (segments.isEmpty ||
        p.timestamp.difference(segments.last.last.timestamp) > gap) {
      segments.add([p]);
    } else {
      segments.last.add(p);
    }
  }
  return segments;
}
