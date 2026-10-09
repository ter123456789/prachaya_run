import 'dart:collection';

import '../services/geo_math.dart';
import 'activity.dart';
import 'activity_type.dart';
import 'track_point.dart';

/// An in-progress recording: filters noisy GPS fixes, tracks pauses and
/// keeps running totals so the UI does not recompute the whole track.
class RecordingSession {
  RecordingSession({
    required this.type,
    required this.startedAt,
    this.maxAccuracyMeters = 30,
    this.minStepMeters = 2,
  }) : _runningSince = startedAt;

  final ActivityType type;
  final DateTime startedAt;

  /// Fixes less accurate than this are dropped.
  final double maxAccuracyMeters;

  /// Fixes closer than this to the previous one are dropped (GPS jitter).
  final double minStepMeters;

  final List<List<TrackPoint>> _segments = [<TrackPoint>[]];
  final ElevationGainCounter _elevation = ElevationGainCounter();
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  double _distance = 0;

  bool get isPaused => _runningSince == null;
  double get distanceMeters => _distance;
  double get elevationGainMeters => _elevation.gain;

  /// Read-only view; it changes as points are added.
  List<List<TrackPoint>> get segments => UnmodifiableListView(_segments);

  Duration movingTime(DateTime now) {
    final since = _runningSince;
    return since == null ? _accumulated : _accumulated + now.difference(since);
  }

  /// Returns whether the point was accepted.
  bool addPoint(TrackPoint point) {
    if (isPaused) return false;
    final accuracy = point.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) return false;

    final current = _segments.last;
    if (current.isNotEmpty) {
      final step = distanceBetween(current.last, point);
      if (step < minStepMeters) return false;
      _distance += step;
    }
    current.add(point);
    _elevation.add(point.altitudeMeters);
    return true;
  }

  void pause(DateTime now) {
    final since = _runningSince;
    if (since == null) return;
    _accumulated += now.difference(since);
    _runningSince = null;
  }

  void resume(DateTime now) {
    if (!isPaused) return;
    _runningSince = now;
    if (_segments.last.isNotEmpty) _segments.add(<TrackPoint>[]);
    _elevation.breakSegment();
  }

  Activity toActivity({
    required String id,
    required String title,
    required DateTime endedAt,
  }) => Activity(
    id: id,
    type: type,
    title: title,
    startedAt: startedAt,
    endedAt: endedAt,
    movingTime: movingTime(endedAt),
    segments: _segments.where((s) => s.isNotEmpty).toList(),
  );
}
