import 'dart:async';
import 'dart:io';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/activity.dart';
import '../../domain/services/activity_sync.dart';
import '../datasources/activity_local_data_source.dart';
import '../datasources/activity_remote_data_source.dart';
import '../datasources/photo_local_data_source.dart';

/// Pushes local changes, then pulls the server's change feed
/// (docs/api.md, "Pull sync"). One run at a time; a request made during a
/// run starts one more run after it, so no change is left behind.
class ActivitySyncEngine implements ActivitySync {
  ActivitySyncEngine({
    required ActivityLocalDataSource local,
    required ActivityRemoteDataSource remote,
    required PhotoLocalDataSource photos,
    required TokenStore tokens,
  }) : _local = local,
       _remote = remote,
       _photos = photos,
       _tokens = tokens;

  static const _epoch = '1970-01-01T00:00:00.000Z';

  final ActivityLocalDataSource _local;
  final ActivityRemoteDataSource _remote;
  final PhotoLocalDataSource _photos;
  final TokenStore _tokens;
  final _changes = StreamController<void>.broadcast();

  Future<SyncOutcome>? _running;
  bool _rerun = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<SyncOutcome> sync() {
    final running = _running;
    if (running != null) {
      _rerun = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  /// Fire-and-forget sync after a local save or delete.
  void schedule() => unawaited(sync());

  /// Downloads the track of an activity pulled from another device.
  /// Null when the server no longer has it.
  Future<Activity?> downloadTrack(String id) async {
    final session = await _tokens.read();
    if (session == null) {
      throw const ApiException(401, 'unauthorized', 'signed out');
    }
    final result = await _remote.download(id);
    if (result == null) {
      await _local.purge(id);
      _changes.add(null);
      return null;
    }
    final (activity, summary) = result;
    await _local.storeDownloaded(activity, summary, ownerId: session.userId);
    return activity;
  }

  Future<SyncOutcome> _loop() async {
    SyncOutcome outcome;
    do {
      _rerun = false;
      outcome = await _runOnce();
    } while (_rerun && outcome == SyncOutcome.synced);
    return outcome;
  }

  Future<SyncOutcome> _runOnce() async {
    final session = await _tokens.read();
    if (session == null) return SyncOutcome.signedOut;
    var changed = false;
    void mark(bool c) => changed |= c;
    try {
      await _local.claimUnowned(session.userId);
      await _photos.claimUnowned(session.userId);
      await _push(session.userId, mark);
      await _pull(session.userId, mark);
      await _syncPhotos(session.userId, mark);
      return SyncOutcome.synced;
    } on NetworkException {
      return SyncOutcome.offline;
    } on ApiException catch (e) {
      return e.status == 401 ? SyncOutcome.signedOut : SyncOutcome.failed;
    } finally {
      if (changed) _changes.add(null);
    }
  }

  Future<void> _push(String userId, void Function(bool changed) mark) async {
    for (final change in await _local.pendingChanges(ownerId: userId)) {
      if (change.deleted) {
        await _remote.delete(change.id);
        await _local.purgeTombstone(change.id, change.updatedAt);
        continue;
      }
      final activity = await _local.activity(change.id);
      if (activity == null) continue;
      final summary = await _remote.upload(
        activity,
        updatedAt: change.updatedAt,
      );
      mark(await _local.confirmUpload(change.id, change.updatedAt, summary));
    }
  }

  /// The cursor is per account, so switching accounts pulls everything.
  Future<void> _pull(String userId, void Function(bool changed) mark) async {
    final key = 'updatedSince:$userId';
    final since = await _local.readSyncValue(key) ?? _epoch;
    String? cursor;
    String serverTime;
    do {
      final page = await _remote.changes(since: since, cursor: cursor);
      for (final item in page.items) {
        mark(await _local.applyRemote(item, ownerId: userId));
      }
      cursor = page.nextCursor;
      serverTime = page.serverTime;
    } while (cursor != null);
    await _local.writeSyncValue(key, serverTime);
  }

  /// After activities: photo deletes, uploads, then lists of activities
  /// whose photos changed elsewhere.
  Future<void> _syncPhotos(
    String userId,
    void Function(bool changed) mark,
  ) async {
    await _photos.pruneOrphans();
    for (final (activityId, photoId) in await _photos.pendingDeletes(userId)) {
      await _remote.deletePhoto(activityId, photoId);
      await _photos.purge(photoId);
    }
    for (final p in await _photos.pendingUploads(userId)) {
      try {
        final bytes = await File(p.path).readAsBytes();
        await _remote.uploadPhoto(
          activityId: p.activityId,
          photoId: p.id,
          bytes: bytes,
          filename: '${p.id}.${imageExtension(bytes)}',
          takenAt: p.takenAt,
        );
        await _photos.markUploaded(p.id);
      } on ApiException catch (e) {
        // Activity gone or file rejected: drop it rather than retry forever.
        if (e.status == 404 || e.status == 413 || e.status == 415) {
          await _photos.purge(p.id);
          mark(true);
        } else {
          rethrow;
        }
      } on FileSystemException {
        await _photos.purge(p.id);
      }
    }
    for (final activityId in await _photos.staleActivities(userId)) {
      final remote = await _remote.photos(activityId);
      if (remote == null) continue;
      mark(
        await _photos.reconcile(
          activityId,
          remote,
          ownerId: userId,
          download: _remote.downloadFile,
        ),
      );
    }
  }
}
