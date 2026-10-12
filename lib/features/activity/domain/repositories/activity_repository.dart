import '../entities/activity.dart';

abstract interface class ActivityRepository {
  Future<void> save(Activity activity);

  /// Newest first.
  Future<List<ActivitySummary>> getAll();

  Future<Activity?> getById(String id);

  Future<void> delete(String id);

  /// Links the activity to [shoeId] (null unlinks). An ordinary edit: it is
  /// stamped with a new edit time and synced.
  Future<void> setShoe(String id, String? shoeId);
}
