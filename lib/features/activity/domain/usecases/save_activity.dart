import '../entities/activity.dart';
import '../entities/recording_session.dart';
import '../repositories/activity_repository.dart';

class ActivityTooShortException implements Exception {
  const ActivityTooShortException();
}

class SaveActivity {
  SaveActivity(this._repository, {this.minDistanceMeters = 50});

  final ActivityRepository _repository;
  final double minDistanceMeters;

  /// Throws [ActivityTooShortException] if the session covered less than
  /// [minDistanceMeters].
  Future<Activity> call(
    RecordingSession session, {
    required String title,
    required DateTime endedAt,
  }) async {
    if (session.distanceMeters < minDistanceMeters) {
      throw const ActivityTooShortException();
    }
    final activity = session.toActivity(
      id: endedAt.microsecondsSinceEpoch.toString(),
      title: title,
      endedAt: endedAt,
    );
    await _repository.save(activity);
    return activity;
  }
}
