import '../../../../core/network/token_store.dart';
import '../../domain/entities/activity_photo.dart';
import '../../domain/repositories/activity_photo_repository.dart';
import '../datasources/photo_local_data_source.dart';
import '../sync/activity_sync_engine.dart';

/// Photos are saved on the device first, then uploaded by the sync.
class OfflineFirstPhotoRepository implements ActivityPhotoRepository {
  OfflineFirstPhotoRepository(this._local, this._sync, this._tokens);

  final PhotoLocalDataSource _local;
  final ActivitySyncEngine _sync;
  final TokenStore _tokens;

  @override
  Future<List<ActivityPhoto>> photosOf(String activityId) =>
      _local.photosOf(activityId);

  @override
  Future<ActivityPhoto> add(
    String activityId,
    List<int> bytes, {
    required DateTime takenAt,
  }) async {
    final photo = await _local.addLocal(
      activityId: activityId,
      bytes: bytes,
      takenAt: takenAt,
      ownerId: (await _tokens.read())?.userId,
    );
    _sync.schedule();
    return photo;
  }

  @override
  Future<void> delete(ActivityPhoto photo) async {
    await _local.markDeleted(photo.id);
    _sync.schedule();
  }
}
