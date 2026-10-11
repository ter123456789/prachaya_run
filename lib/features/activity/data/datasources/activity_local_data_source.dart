import 'package:sqflite/sqflite.dart';

import '../../domain/entities/activity.dart';
import '../models/activity_row_mapper.dart';
import '../models/remote_activity_summary.dart';
import 'app_database.dart';

/// Sync bookkeeping of one local activity row.
class LocalSyncState {
  const LocalSyncState({
    required this.ownerId,
    required this.updatedAtMs,
    required this.synced,
    required this.deleted,
    required this.hasTrack,
    this.photoCount = 0,
  });

  /// The server's photo count last seen.
  final int photoCount;

  /// Null while unclaimed (recorded signed out).
  final String? ownerId;
  final int updatedAtMs;
  final bool synced;
  final bool deleted;
  final bool hasTrack;
}

/// A local change the server has not seen yet.
class PendingChange {
  const PendingChange({
    required this.id,
    required this.updatedAt,
    required this.deleted,
  });

  final String id;
  final DateTime updatedAt;
  final bool deleted;
}

/// All SQL for activities, including the sync columns added in v2.
///
/// Rows are scoped by account: signed in as `u`, the app sees rows owned by
/// `u` plus unclaimed ones (recorded signed out); signed out, only
/// unclaimed ones. Other accounts' rows stay on disk, hidden.
class ActivityLocalDataSource {
  ActivityLocalDataSource(this._db);

  final Database _db;

  static const _activities = AppDatabase.activitiesTable;
  static const _points = AppDatabase.trackPointsTable;

  Future<void> saveLocal(
    Activity activity, {
    required DateTime updatedAt,
    required String? ownerId,
  }) {
    return _db.transaction((txn) async {
      await txn.insert(
        _activities,
        ActivityRowMapper.activityToRow(
          activity,
          updatedAt: updatedAt,
          ownerId: ownerId,
        ),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceTrack(txn, activity);
    });
  }

  /// Newest first, without deleted ones, for the account [ownerId].
  Future<List<ActivitySummary>> summaries({required String? ownerId}) async {
    final (visible, args) = _visibleTo(ownerId);
    final rows = await _db.query(
      _activities,
      where: 'deleted_at IS NULL AND $visible',
      whereArgs: args,
      orderBy: 'started_at DESC',
    );
    return rows.map(ActivityRowMapper.summaryFromRow).toList();
  }

  Future<LocalSyncState?> syncState(String id) => _syncState(_db, id);

  /// The activity with its stored track; null when missing or deleted.
  /// Callers check ownership first (see [syncState]).
  Future<Activity?> activity(String id) async {
    final rows = await _db.query(
      _activities,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final points = await _db.query(
      _points,
      where: 'activity_id = ?',
      whereArgs: [id],
      orderBy: 'segment, seq',
    );
    return ActivityRowMapper.activityFromRows(rows.first, points);
  }

  /// Keeps a tombstone until the server confirms the delete.
  Future<void> markDeleted(String id, {required DateTime at}) {
    return _db.transaction((txn) async {
      await _deleteTrack(txn, id);
      await txn.update(
        _activities,
        {
          'deleted_at': at.millisecondsSinceEpoch,
          'updated_at': at.millisecondsSinceEpoch,
          'synced': 0,
          'has_track': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Deletes everything an account owns on this device (account deleted).
  Future<void> purgeOwner(String ownerId) =>
      _db.delete(_activities, where: 'owner_id = ?', whereArgs: [ownerId]);

  /// Activities recorded while signed out (not yet claimed by an account).
  Future<int> unclaimedCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_activities '
      'WHERE owner_id IS NULL AND deleted_at IS NULL',
    );
    return rows.first['n']! as int;
  }

  /// Gives activities recorded while signed out to [ownerId].
  Future<void> claimUnowned(String ownerId) =>
      _db.update(_activities, {'owner_id': ownerId}, where: 'owner_id IS NULL');

  Future<List<PendingChange>> pendingChanges({required String ownerId}) async {
    final rows = await _db.query(
      _activities,
      columns: ['id', 'updated_at', 'deleted_at'],
      where: 'synced = 0 AND owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'updated_at',
    );
    return [
      for (final r in rows)
        PendingChange(
          id: r['id']! as String,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            r['updated_at']! as int,
          ),
          deleted: r['deleted_at'] != null,
        ),
    ];
  }

  /// Removes the row for good (server delete confirmed or seen).
  Future<void> purge(String id) =>
      _db.delete(_activities, where: 'id = ?', whereArgs: [id]);

  /// Removes a tombstone once the server has it, unless the row changed
  /// again meanwhile.
  Future<void> purgeTombstone(String id, DateTime updatedAt) => _db.delete(
    _activities,
    where: 'id = ? AND deleted_at IS NOT NULL AND updated_at = ?',
    whereArgs: [id, updatedAt.millisecondsSinceEpoch],
  );

  /// Records the server's answer to an upload of the version stamped
  /// [pushedAt]. Returns whether the local data visibly changed.
  Future<bool> confirmUpload(
    String id,
    DateTime pushedAt,
    RemoteActivitySummary s,
  ) {
    return _db.transaction((txn) async {
      final state = await _syncState(txn, id);
      // Edited again while uploading: the newer edit goes up next time.
      if (state == null ||
          state.ownerId == null ||
          state.updatedAtMs != pushedAt.millisecondsSinceEpoch) {
        return false;
      }
      if (s.isDeleted) {
        await txn.delete(_activities, where: 'id = ?', whereArgs: [id]);
        return true;
      }
      final serverIsNewer =
          s.updatedAt.millisecondsSinceEpoch != pushedAt.millisecondsSinceEpoch;
      if (serverIsNewer) await _deleteTrack(txn, id);
      await txn.update(
        _activities,
        ActivityRowMapper.remoteSummaryToRow(
          s,
          hasTrack: !serverIsNewer,
          ownerId: state.ownerId!,
        ),
        where: 'id = ?',
        whereArgs: [id],
      );
      return serverIsNewer;
    });
  }

  /// Applies one item of [ownerId]'s pull feed. Returns whether anything
  /// changed.
  Future<bool> applyRemote(RemoteActivitySummary s, {required String ownerId}) {
    return _db.transaction((txn) async {
      final state = await _syncState(txn, s.id);
      // Ids are UUIDs; a row of another account is never touched.
      if (state != null && state.ownerId != ownerId) return false;
      if (s.isDeleted) {
        if (state == null) return false;
        await txn.delete(_activities, where: 'id = ?', whereArgs: [s.id]);
        return true;
      }
      final remoteMs = s.updatedAt.millisecondsSinceEpoch;
      if (state != null) {
        // A local edit at least as new wins; it is uploaded next.
        if (!state.synced && state.updatedAtMs >= remoteMs) return false;
        if (state.synced && state.updatedAtMs == remoteMs) {
          // Same activity; only its photos may have changed elsewhere.
          if (state.photoCount == s.photoCount) return false;
          await txn.update(
            _activities,
            {'photo_count': s.photoCount, 'photos_stale': 1},
            where: 'id = ?',
            whereArgs: [s.id],
          );
          return true;
        }
        await _deleteTrack(txn, s.id);
      }
      await txn.insert(_activities, {
        ...ActivityRowMapper.remoteSummaryToRow(
          s,
          hasTrack: false,
          ownerId: ownerId,
        ),
        'photos_stale': s.photoCount > 0 || (state?.photoCount ?? 0) > 0
            ? 1
            : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// Stores a track downloaded for an activity that was pulled without one.
  Future<void> storeDownloaded(
    Activity activity,
    RemoteActivitySummary s, {
    required String ownerId,
  }) {
    return _db.transaction((txn) async {
      final state = await _syncState(txn, activity.id);
      if (state != null &&
          (!state.synced || state.deleted || state.ownerId != ownerId)) {
        return;
      }
      final row = ActivityRowMapper.remoteSummaryToRow(
        s,
        hasTrack: true,
        ownerId: ownerId,
      );
      if (state == null) {
        await txn.insert(_activities, {
          ...row,
          'photos_stale': s.photoCount > 0 ? 1 : 0,
        });
      } else {
        // Update in place: keeps photos_stale.
        await txn.update(
          _activities,
          row,
          where: 'id = ?',
          whereArgs: [activity.id],
        );
      }
      await _replaceTrack(txn, activity);
    });
  }

  Future<String?> readSyncValue(String key) async {
    final rows = await _db.query(
      AppDatabase.syncStateTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> writeSyncValue(String key, String value) => _db.insert(
    AppDatabase.syncStateTable,
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  /// Rows [ownerId] may see: its own plus unclaimed ones.
  static (String, List<Object?>) _visibleTo(String? ownerId) => ownerId == null
      ? ('owner_id IS NULL', const [])
      : ('(owner_id IS NULL OR owner_id = ?)', [ownerId]);

  static Future<LocalSyncState?> _syncState(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      _activities,
      columns: [
        'owner_id',
        'updated_at',
        'synced',
        'deleted_at',
        'has_track',
        'photo_count',
      ],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return LocalSyncState(
      ownerId: r['owner_id'] as String?,
      updatedAtMs: r['updated_at']! as int,
      synced: r['synced'] == 1,
      deleted: r['deleted_at'] != null,
      hasTrack: r['has_track'] == 1,
      photoCount: r['photo_count'] as int? ?? 0,
    );
  }

  static Future<void> _deleteTrack(DatabaseExecutor db, String id) =>
      db.delete(_points, where: 'activity_id = ?', whereArgs: [id]);

  static Future<void> _replaceTrack(Transaction txn, Activity activity) async {
    await _deleteTrack(txn, activity.id);
    final batch = txn.batch();
    for (final row in ActivityRowMapper.pointsToRows(activity)) {
      batch.insert(_points, row);
    }
    await batch.commit(noResult: true);
  }
}
