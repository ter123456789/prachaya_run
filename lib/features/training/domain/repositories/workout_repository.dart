import '../entities/planned_workout.dart';

abstract interface class WorkoutRepository {
  /// The current account's planned workouts (or the device's when signed
  /// out), by scheduled time.
  Future<List<PlannedWorkout>> getAll();

  /// Adds or replaces a workout. Throws [WorkoutValidationException] for
  /// invalid values.
  Future<void> save(PlannedWorkout workout);

  Future<void> delete(String id);
}
