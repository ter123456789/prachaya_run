/// Kinds of training session (Stitch "Workout Types").
enum WorkoutType { easy, tempo, interval, long, rest }

/// A session planned for a day and time. Rest days have no distance or
/// pace.
class PlannedWorkout {
  const PlannedWorkout({
    required this.id,
    required this.type,
    required this.title,
    required this.scheduledAt,
    this.location,
    this.distanceMeters = 0,
    this.paceMinSecPerKm,
    this.paceMaxSecPerKm,
    this.completedActivityId,
  });

  final String id;
  final WorkoutType type;
  final String title;
  final DateTime scheduledAt;
  final String? location;
  final double distanceMeters;

  /// Target pace range (fast end, slow end), seconds per km.
  final int? paceMinSecPerKm;
  final int? paceMaxSecPerKm;

  /// The recorded run that fulfilled this session.
  final String? completedActivityId;

  bool get isRest => type == WorkoutType.rest;
  bool get isCompleted => completedActivityId != null;

  PlannedWorkout copyWith({
    WorkoutType? type,
    String? title,
    DateTime? scheduledAt,
    String? Function()? location,
    double? distanceMeters,
    int? Function()? paceMinSecPerKm,
    int? Function()? paceMaxSecPerKm,
    String? Function()? completedActivityId,
  }) => PlannedWorkout(
    id: id,
    type: type ?? this.type,
    title: title ?? this.title,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    location: location == null ? this.location : location(),
    distanceMeters: distanceMeters ?? this.distanceMeters,
    paceMinSecPerKm: paceMinSecPerKm == null
        ? this.paceMinSecPerKm
        : paceMinSecPerKm(),
    paceMaxSecPerKm: paceMaxSecPerKm == null
        ? this.paceMaxSecPerKm
        : paceMaxSecPerKm(),
    completedActivityId: completedActivityId == null
        ? this.completedActivityId
        : completedActivityId(),
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedWorkout &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.scheduledAt == scheduledAt &&
      other.location == location &&
      other.distanceMeters == distanceMeters &&
      other.paceMinSecPerKm == paceMinSecPerKm &&
      other.paceMaxSecPerKm == paceMaxSecPerKm &&
      other.completedActivityId == completedActivityId;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    scheduledAt,
    location,
    distanceMeters,
    paceMinSecPerKm,
    paceMaxSecPerKm,
    completedActivityId,
  );

  @override
  String toString() => 'PlannedWorkout($id, $type, $title, $scheduledAt)';
}

class WorkoutValidationException implements Exception {
  const WorkoutValidationException();
}
