import '../entities/activity.dart';

abstract interface class ActivityRepository {
  Future<void> save(Activity activity);

  /// Newest first.
  Future<List<ActivitySummary>> getAll();

  Future<Activity?> getById(String id);

  Future<void> delete(String id);
}
