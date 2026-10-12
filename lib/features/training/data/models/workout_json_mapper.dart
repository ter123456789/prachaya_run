import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/planned_workout.dart';

/// PlannedWorkout ↔ the API object (docs/api.md v1.2, Planned workouts)
/// without the bookkeeping fields, which the record store keeps itself.
abstract final class WorkoutJsonMapper {
  static Json toJson(PlannedWorkout w) => {
    'type': w.type.name,
    'title': w.title,
    'location': w.location,
    'scheduledAt': DateTime.fromMillisecondsSinceEpoch(
      w.scheduledAt.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String(),
    'distanceM': w.distanceMeters,
    'paceMinSecPerKm': w.paceMinSecPerKm,
    'paceMaxSecPerKm': w.paceMaxSecPerKm,
    'completedActivityId': w.completedActivityId,
  };

  static PlannedWorkout fromJson(String id, Json json) => PlannedWorkout(
    id: id,
    type: WorkoutType.values.byName(json['type']! as String),
    title: json['title']! as String,
    location: json['location'] as String?,
    scheduledAt: DateTime.parse(json['scheduledAt']! as String).toLocal(),
    distanceMeters: (json['distanceM'] as num?)?.toDouble() ?? 0,
    paceMinSecPerKm: (json['paceMinSecPerKm'] as num?)?.toInt(),
    paceMaxSecPerKm: (json['paceMaxSecPerKm'] as num?)?.toInt(),
    completedActivityId: json['completedActivityId'] as String?,
  );
}
