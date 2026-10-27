import 'heart_rate.dart';
import 'track_point.dart';

/// What a watch app called the workout (others are not imported).
enum WorkoutKind { run, ride, hike, walk }

/// A workout another app (Samsung Health, Garmin Connect, Apple Workout…)
/// wrote to Apple Health / Health Connect, as listed: no route or heart
/// rate yet ([WorkoutDetail] has those).
class ImportedWorkout {
  const ImportedWorkout({
    required this.source,
    required this.externalId,
    required this.kind,
    required this.start,
    required this.end,
    this.activeTime,
    this.distanceMeters,
    this.elevationGainMeters,
    this.app,
    this.device,
  });

  /// `health-connect` or `healthkit`: with [externalId], the name of the
  /// activity's stable id (api.md v1.6).
  final String source;
  final String externalId;
  final WorkoutKind kind;
  final DateTime start;
  final DateTime end;

  /// Time moving, when the watch app records pauses.
  final Duration? activeTime;
  final double? distanceMeters;
  final double? elevationGainMeters;
  final String? app;
  final String? device;
}

class WorkoutDetail {
  const WorkoutDetail({this.route = const [], this.heartRate = const []});

  /// Oldest first; empty when the app shared no route.
  final List<TrackPoint> route;
  final List<HeartRateSample> heartRate;
}
