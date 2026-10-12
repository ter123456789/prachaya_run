import '../../../activity/domain/entities/activity.dart';
import '../repositories/workout_repository.dart';
import '../services/workout_plan.dart';

/// After a run is saved, ticks off the session it fulfils (if any).
class CompleteWorkoutForActivity {
  CompleteWorkoutForActivity(this._workouts);

  final WorkoutRepository _workouts;

  /// Returns whether a session was marked done.
  Future<bool> call(Activity activity) async {
    final match = workoutFulfilledBy(
      activity.summary,
      await _workouts.getAll(),
    );
    if (match == null) return false;
    await _workouts.save(
      match.copyWith(completedActivityId: () => activity.id),
    );
    return true;
  }
}
