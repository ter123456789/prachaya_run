import '../entities/activity.dart';
import '../entities/recording_session.dart';
import '../repositories/activity_repository.dart';
import '../services/uuid.dart';

class ActivityTooShortException implements Exception {
  const ActivityTooShortException();
}

class SaveActivity {
  SaveActivity(
    this._repository, {
    this.minDistanceMeters = 50,
    String Function() newId = uuidV4,
  }) : _newId = newId;

  final ActivityRepository _repository;
  final double minDistanceMeters;
  final String Function() _newId;

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
      id: _newId(),
      title: title,
      endedAt: endedAt,
    );
    await _repository.save(activity);
    return activity;
  }
}
