import '../../../../core/network/token_store.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_local_data_source.dart';
import '../datasources/photo_local_data_source.dart';
import '../sync/activity_sync_engine.dart';

/// Reads and writes go to SQLite first, so recording works offline;
/// every change then triggers a background sync.
///
/// Scoped to the signed-in account: its activities plus ones recorded while
/// signed out (claimed by the account on its next sync).
class OfflineFirstActivityRepository implements ActivityRepository {
  OfflineFirstActivityRepository(
    this._local,
    this._sync,
    this._tokens, {
    PhotoLocalDataSource? photos,
    DateTime Function() clock = DateTime.now,
  }) : _photos = photos,
       _clock = clock;

  final ActivityLocalDataSource _local;
  final ActivitySyncEngine _sync;
  final TokenStore _tokens;
  final PhotoLocalDataSource? _photos;
  final DateTime Function() _clock;

  Future<String?> _owner() async => (await _tokens.read())?.userId;

  @override
  Future<void> save(Activity activity) async {
    await _local.saveLocal(
      activity,
      updatedAt: _clock(),
      ownerId: await _owner(),
    );
    _sync.schedule();
  }

  @override
  Future<List<ActivitySummary>> getAll() async =>
      _local.summaries(ownerId: await _owner());

  /// Downloads the track first when the activity came from another device.
  @override
  Future<Activity?> getById(String id) async {
    final state = await _local.syncState(id);
    if (state == null || state.deleted || !await _visible(state)) return null;
    if (state.hasTrack) return _local.activity(id);
    return _sync.downloadTrack(id);
  }

  @override
  Future<void> delete(String id) async {
    final state = await _local.syncState(id);
    if (state == null || !await _visible(state)) return;
    await _local.markDeleted(id, at: _clock());
    // The server deletes an activity's photos with it.
    await _photos?.removeAllOf(id);
    _sync.schedule();
  }

  Future<bool> _visible(LocalSyncState state) async =>
      state.ownerId == null || state.ownerId == await _owner();
}
