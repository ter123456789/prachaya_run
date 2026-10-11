import '../entities/activity_photo.dart';

abstract interface class ActivityPhotoRepository {
  /// Oldest first.
  Future<List<ActivityPhoto>> photosOf(String activityId);

  /// Saves [bytes] (JPEG/PNG/HEIC) and queues the upload.
  Future<ActivityPhoto> add(
    String activityId,
    List<int> bytes, {
    required DateTime takenAt,
  });

  Future<void> delete(ActivityPhoto photo);
}
