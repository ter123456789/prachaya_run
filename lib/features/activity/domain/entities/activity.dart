import '../services/geo_math.dart';
import 'activity_origin.dart';
import 'activity_type.dart';
import 'heart_rate.dart';
import 'track_point.dart';

/// A finished, saved activity. [segments] are separated by pauses.
///
/// An activity imported from a watch may have no points at all (treadmill,
/// or an app that shares no route); its distance and climb then come from
/// the watch ([reportedDistanceMeters], [reportedElevationGainMeters]).
class Activity {
  Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.movingTime,
    required List<List<TrackPoint>> segments,
    this.shoeId,
    this.heartRate,
    this.origin = ActivityOrigin.phone,
    this.reportedDistanceMeters,
    this.reportedElevationGainMeters,
  }) : segments = List<List<TrackPoint>>.unmodifiable(
         segments.map(List<TrackPoint>.unmodifiable),
       );

  final String id;
  final ActivityType type;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration movingTime;
  final List<List<TrackPoint>> segments;

  /// The shoe this activity counts toward; null when none is linked.
  final String? shoeId;

  /// Null when recorded without a heart-rate sensor.
  final HeartRateTrack? heartRate;

  final ActivityOrigin origin;

  /// Used only when there are no points.
  final double? reportedDistanceMeters;
  final double? reportedElevationGainMeters;

  /// At least one GPS point (imported activities may have none).
  bool get hasTrack => segments.any((s) => s.isNotEmpty);

  late final double distanceMeters = _computeDistance();
  late final double elevationGainMeters = _computeElevationGain();

  ActivitySummary get summary => ActivitySummary(
    id: id,
    type: type,
    title: title,
    startedAt: startedAt,
    movingTime: movingTime,
    distanceMeters: distanceMeters,
    elevationGainMeters: elevationGainMeters,
    shoeId: shoeId,
    endedAt: endedAt,
    origin: origin,
  );

  /// The same activity linked to [shoeId] (null unlinks it).
  Activity withShoe(String? shoeId) => _copy(shoeId: () => shoeId);

  /// The same activity with [heartRate] (e.g. back-filled from Health).
  Activity withHeartRate(HeartRateTrack? heartRate) =>
      _copy(heartRate: () => heartRate);

  Activity _copy({
    String? Function()? shoeId,
    HeartRateTrack? Function()? heartRate,
  }) => Activity(
    id: id,
    type: type,
    title: title,
    startedAt: startedAt,
    endedAt: endedAt,
    movingTime: movingTime,
    segments: segments,
    shoeId: shoeId == null ? this.shoeId : shoeId(),
    heartRate: heartRate == null ? this.heartRate : heartRate(),
    origin: origin,
    reportedDistanceMeters: reportedDistanceMeters,
    reportedElevationGainMeters: reportedElevationGainMeters,
  );

  /// Splits of [every] meters, timed by GPS timestamps (pauses excluded).
  /// The last split may be shorter than [every].
  List<ActivitySplit> splits({double every = 1000}) {
    final result = <ActivitySplit>[];
    var splitDistance = 0.0;
    var splitTime = Duration.zero;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        var stepDistance = distanceBetween(segment[i - 1], segment[i]);
        var stepTime = segment[i].timestamp.difference(
          segment[i - 1].timestamp,
        );
        while (splitDistance + stepDistance >= every) {
          final needed = every - splitDistance;
          final partTime = stepTime * (needed / stepDistance);
          result.add(
            ActivitySplit(
              index: result.length + 1,
              distanceMeters: every,
              duration: splitTime + partTime,
            ),
          );
          stepDistance -= needed;
          stepTime -= partTime;
          splitDistance = 0;
          splitTime = Duration.zero;
        }
        splitDistance += stepDistance;
        splitTime += stepTime;
      }
    }
    if (splitDistance >= 1) {
      result.add(
        ActivitySplit(
          index: result.length + 1,
          distanceMeters: splitDistance,
          duration: splitTime,
        ),
      );
    }
    return result;
  }

  double _computeDistance() {
    if (!hasTrack) return reportedDistanceMeters ?? 0;
    var total = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        total += distanceBetween(segment[i - 1], segment[i]);
      }
    }
    return total;
  }

  double _computeElevationGain() {
    if (!hasTrack) return reportedElevationGainMeters ?? 0;
    final counter = ElevationGainCounter();
    for (final segment in segments) {
      counter.breakSegment();
      for (final point in segment) {
        counter.add(point.altitudeMeters);
      }
    }
    return counter.gain;
  }
}

/// Lightweight view of an activity for lists, without the GPS track.
class ActivitySummary {
  const ActivitySummary({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.movingTime,
    required this.distanceMeters,
    required this.elevationGainMeters,
    this.shoeId,
    this.endedAt,
    this.origin = ActivityOrigin.phone,
  });

  final String id;
  final ActivityType type;
  final String title;
  final DateTime startedAt;
  final Duration movingTime;
  final double distanceMeters;
  final double elevationGainMeters;
  final String? shoeId;

  /// Null where only the start is known (older callers); see [end].
  final DateTime? endedAt;
  final ActivityOrigin origin;

  /// [endedAt], or the start plus the moving time.
  DateTime get end => endedAt ?? startedAt.add(movingTime);

  double get averageSpeedMps => _speed(distanceMeters, movingTime);
}

class ActivitySplit {
  const ActivitySplit({
    required this.index,
    required this.distanceMeters,
    required this.duration,
  });

  final int index;
  final double distanceMeters;
  final Duration duration;

  double get averageSpeedMps => _speed(distanceMeters, duration);
}

double _speed(double meters, Duration time) {
  final seconds = time.inMilliseconds / 1000;
  return seconds <= 0 ? 0 : meters / seconds;
}
