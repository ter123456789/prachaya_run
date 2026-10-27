import 'dart:collection';

import '../services/geo_math.dart';
import 'activity.dart';
import 'activity_type.dart';
import 'heart_rate.dart';
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
  final List<LapMark> _laps = [];
  final List<HeartRateSample> _heartRate = [];
  ElevationGainCounter _elevation = ElevationGainCounter();
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  DateTime? _pausedAt;
  double _distance = 0;

  bool get isPaused => _runningSince == null;
  double get distanceMeters => _distance;
  double get elevationGainMeters => _elevation.gain;

  /// Where each finished lap ended (live only: activities keep no laps).
  List<LapMark> get laps => UnmodifiableListView(_laps);

  /// 1 for the first lap.
  int get lapNumber => _laps.length + 1;

  /// Ends the current lap at the distance and moving time so far. Ignored
  /// while paused or before anything was covered since the last lap.
  bool lap(DateTime now) {
    if (isPaused) return false;
    final last = _laps.isEmpty ? null : _laps.last;
    if (_distance <= (last?.distanceMeters ?? 0)) return false;
    _laps.add(LapMark(distanceMeters: _distance, movingTime: movingTime(now)));
    return true;
  }

  /// Read-only view; it changes as points are added.
  List<List<TrackPoint>> get segments => UnmodifiableListView(_segments);

  /// Heart rate from a sensor, oldest first (read-only view).
  List<HeartRateSample> get heartRate => UnmodifiableListView(_heartRate);

  /// Keeps at most one sample per whole second since the start (the
  /// latest); ignored while paused. Returns whether it was kept.
  bool addHeartRate(int bpm, DateTime at) {
    if (isPaused) return false;
    final sample = HeartRateSample(timestamp: at, bpm: bpm);
    if (_heartRate.isNotEmpty) {
      final last = _heartRate.last;
      if (at.isBefore(last.timestamp)) return false;
      int second(DateTime t) => t.difference(startedAt).inSeconds;
      if (second(at) == second(last.timestamp)) {
        _heartRate.last = sample;
        return true;
      }
    }
    _heartRate.add(sample);
    return true;
  }

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
    _pausedAt = now;
  }

  /// Pauses as if it had happened at [from] (when a vehicle ride began):
  /// fixes after it are dropped and that stretch's distance and time no
  /// longer count. Laps ended inside it are dropped too.
  void pauseFrom(DateTime from, DateTime now) {
    final since = _runningSince;
    if (since == null) return;
    final at = _clamp(from, since, now);
    _segments.last.removeWhere((p) => p.timestamp.isAfter(at));
    _heartRate.removeWhere((s) => s.timestamp.isAfter(at));
    _recount();
    pause(at);
    _laps.removeWhere(
      (lap) => lap.distanceMeters > _distance || lap.movingTime > _accumulated,
    );
  }

  void resume(DateTime now) {
    if (!isPaused) return;
    _runningSince = now;
    if (_segments.last.isNotEmpty) _segments.add(<TrackPoint>[]);
    _elevation.breakSegment();
  }

  /// Resumes as if it had happened at [from] (when the athlete left the
  /// vehicle) and adds the [fixes] recorded since.
  void resumeFrom(DateTime from, Iterable<TrackPoint> fixes, DateTime now) {
    if (!isPaused) return;
    resume(_clamp(from, _pausedAt ?? from, now));
    for (final fix in fixes) {
      if (!fix.timestamp.isBefore(from)) addPoint(fix);
    }
  }

  static DateTime _clamp(DateTime t, DateTime min, DateTime max) =>
      t.isBefore(min) ? min : (t.isAfter(max) ? max : t);

  void _recount() {
    _distance = 0;
    _elevation = ElevationGainCounter();
    for (final segment in _segments) {
      for (var i = 0; i < segment.length; i++) {
        if (i > 0) _distance += distanceBetween(segment[i - 1], segment[i]);
        _elevation.add(segment[i].altitudeMeters);
      }
      _elevation.breakSegment();
    }
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
    heartRate: _heartRate.isEmpty
        ? null
        : HeartRateTrack(source: HeartRateSource.ble, samples: _heartRate),
  );
}

/// The end of one lap: distance and moving time from the start.
class LapMark {
  const LapMark({required this.distanceMeters, required this.movingTime});

  final double distanceMeters;
  final Duration movingTime;
}
