import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'device_owner.dart';

typedef Json = Map<String, Object?>;

/// A small record as stored on the device.
class StoredRecord {
  const StoredRecord({
    required this.id,
    required this.ownerId,
    required this.data,
    required this.updatedAt,
    required this.deleted,
    required this.synced,
  });

  final String id;

  /// Null while unclaimed (made signed out).
  final String? ownerId;
  final Json data;
  final DateTime updatedAt;
  final bool deleted;
  final bool synced;
}

/// A record as the server returns it.
class RemoteRecord {
  const RemoteRecord({
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Splits the API object into bookkeeping fields and [data].
  factory RemoteRecord.fromJson(Json json) => RemoteRecord(
    id: json['id']! as String,
    updatedAt: DateTime.parse(json['updatedAt']! as String).toLocal(),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt']! as String).toLocal(),
    data: {
      for (final e in json.entries)
        if (!const {'id', 'updatedAt', 'deletedAt'}.contains(e.key))
          e.key: e.value,
    },
  );

  final String id;
  final Json data;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

/// SQL for one table of offline-first records (`shoes`,
/// `planned_workouts`, `planned_routes`), with the same rules as activities: rows are scoped
/// by `owner_id`, edits are last-write-wins on `updated_at`, deletes keep a
/// tombstone until the server confirms them.
class SyncedRecordStore {
  SyncedRecordStore(this._db, this.table);

  final Database _db;
  final String table;

  /// Records [ownerId] may see (its own plus unclaimed), without deleted.
  Future<List<StoredRecord>> visible(String? ownerId) async {
    final (where, args) = ownerId == null
        ? ('owner_id IS NULL', const <Object?>[])
        : ('(owner_id IS NULL OR owner_id = ?)', [ownerId]);
    final rows = await _db.query(
      table,
      where: 'deleted_at IS NULL AND $where',
      whereArgs: args,
    );
    return rows.map(_fromRow).toList();
  }

  Future<StoredRecord?> get(String id) async {
    final rows = await _db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// A local edit, waiting to be pushed.
  Future<void> putLocal(
    String id,
    Json data, {
    required DateTime updatedAt,
    required String? ownerId,
  }) => _db.insert(table, {
    'id': id,
    'owner_id': ownerId,
    'data': jsonEncode(data),
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'synced': 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> markDeleted(String id, {required DateTime at}) => _db.update(
    table,
    {
      'deleted_at': at.millisecondsSinceEpoch,
      'updated_at': at.millisecondsSinceEpoch,
      'synced': 0,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  /// See ActivityLocalDataSource.parkUnowned.
  Future<void> parkUnowned() => _db.update(table, {
    'owner_id': kDeviceOnlyOwner,
  }, where: 'owner_id IS NULL');

  Future<void> restoreDeviceOnly() => _db.update(
    table,
    {'owner_id': null},
    where: 'owner_id = ?',
    whereArgs: [kDeviceOnlyOwner],
  );

  Future<void> claimUnowned(String ownerId) =>
      _db.update(table, {'owner_id': ownerId}, where: 'owner_id IS NULL');

  /// Signed out ([ownerId] null): unclaimed records still to be sent once
  /// an account signs in.
  Future<int> pendingCount(String? ownerId) async {
    final rows = ownerId == null
        ? await _db.rawQuery(
            'SELECT COUNT(*) AS n FROM $table '
            'WHERE owner_id IS NULL AND deleted_at IS NULL',
          )
        : await _db.rawQuery(
            'SELECT COUNT(*) AS n FROM $table '
            'WHERE synced = 0 AND owner_id = ?',
            [ownerId],
          );
    return rows.first['n']! as int;
  }

  Future<List<StoredRecord>> pending(String ownerId) async {
    final rows = await _db.query(
      table,
      where: 'synced = 0 AND owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'updated_at',
    );
    return rows.map(_fromRow).toList();
  }

  /// Removes a tombstone once the server has it, unless it changed again.
  Future<void> purgeTombstone(String id, DateTime updatedAt) => _db.delete(
    table,
    where: 'id = ? AND deleted_at IS NOT NULL AND updated_at = ?',
    whereArgs: [id, updatedAt.millisecondsSinceEpoch],
  );

  Future<void> purgeOwner(String ownerId) =>
      _db.delete(table, where: 'owner_id = ?', whereArgs: [ownerId]);

  /// Records the server's answer to a push of the version stamped
  /// [pushedAt]. Returns whether local data visibly changed.
  Future<bool> confirmPush(String id, DateTime pushedAt, RemoteRecord r) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final local = _fromRow(rows.first);
      // Edited again while pushing: the newer edit goes up next time.
      if (local.ownerId == null ||
          local.updatedAt.millisecondsSinceEpoch !=
              pushedAt.millisecondsSinceEpoch) {
        return false;
      }
      if (r.isDeleted) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        return true;
      }
      final serverIsNewer =
          r.updatedAt.millisecondsSinceEpoch != pushedAt.millisecondsSinceEpoch;
      await txn.update(
        table,
        _remoteRow(r, local.ownerId!),
        where: 'id = ?',
        whereArgs: [id],
      );
      return serverIsNewer;
    });
  }

  /// Applies one item of [ownerId]'s pull feed. Returns whether anything
  /// changed.
  Future<bool> applyRemote(RemoteRecord r, {required String ownerId}) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        table,
        where: 'id = ?',
        whereArgs: [r.id],
        limit: 1,
      );
      final local = rows.isEmpty ? null : _fromRow(rows.first);
      // Ids are UUIDs; another account's row is never touched.
      if (local != null && local.ownerId != ownerId) return false;
      if (r.isDeleted) {
        if (local == null) return false;
        await txn.delete(table, where: 'id = ?', whereArgs: [r.id]);
        return true;
      }
      final remoteMs = r.updatedAt.millisecondsSinceEpoch;
      if (local != null) {
        final localMs = local.updatedAt.millisecondsSinceEpoch;
        // A local edit at least as new wins; it is pushed next.
        if (!local.synced && localMs >= remoteMs) return false;
        if (local.synced && localMs == remoteMs) return false;
      }
      await txn.insert(
        table,
        _remoteRow(r, ownerId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    });
  }

  /// Sync cursor per account, in the shared `sync_state` table.
  Future<String?> readCursor(String key) async {
    final rows = await _db.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> writeCursor(String key, String value) => _db.insert(
    'sync_state',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  static Map<String, Object?> _remoteRow(RemoteRecord r, String ownerId) => {
    'id': r.id,
    'owner_id': ownerId,
    'data': jsonEncode(r.data),
    'updated_at': r.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'synced': 1,
  };

  static StoredRecord _fromRow(Map<String, Object?> row) => StoredRecord(
    id: row['id']! as String,
    ownerId: row['owner_id'] as String?,
    data: jsonDecode(row['data']! as String) as Json,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    deleted: row['deleted_at'] != null,
    synced: row['synced'] == 1,
  );
}
