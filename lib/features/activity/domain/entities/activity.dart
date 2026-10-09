import '../services/geo_math.dart';
import 'activity_type.dart';
import 'track_point.dart';

/// A finished, saved activity. [segments] are separated by pauses.
class Activity {
  Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.movingTime,
    required List<List<TrackPoint>> segments,
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
    var total = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        total += distanceBetween(segment[i - 1], segment[i]);
      }
    }
    return total;
  }

  double _computeElevationGain() {
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
  });

  final String id;
  final ActivityType type;
  final String title;
  final DateTime startedAt;
  final Duration movingTime;
  final double distanceMeters;
  final double elevationGainMeters;

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
