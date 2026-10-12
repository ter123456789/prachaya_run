import '../entities/activity.dart';
import '../entities/activity_type.dart';
import '../entities/recording_session.dart';
import '../repositories/activity_repository.dart';
import '../services/uuid.dart';

class ActivityTooShortException implements Exception {
  const ActivityTooShortException();
}

/// The shoe a new activity of [type] counts toward (the primary shoe), or
/// null. Supplied by the gear feature.
typedef DefaultShoe = Future<String?> Function(ActivityType type);

/// Runs after a save, e.g. to tick off today's planned workout.
typedef ActivitySavedHook = Future<void> Function(Activity activity);

class SaveActivity {
  SaveActivity(
    this._repository, {
    this.minDistanceMeters = 50,
    String Function() newId = uuidV4,
    DefaultShoe? defaultShoe,
    List<ActivitySavedHook> onSaved = const [],
  }) : _newId = newId,
       _defaultShoe = defaultShoe,
       _onSaved = onSaved;

  final ActivityRepository _repository;
  final double minDistanceMeters;
  final String Function() _newId;
  final DefaultShoe? _defaultShoe;
  final List<ActivitySavedHook> _onSaved;

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
    var activity = session.toActivity(
      id: _newId(),
      title: title,
      endedAt: endedAt,
    );
    final shoe = await _defaultShoe?.call(activity.type);
    if (shoe != null) activity = activity.withShoe(shoe);
    await _repository.save(activity);
    for (final hook in _onSaved) {
      await hook(activity);
    }
    return activity;
  }
}
