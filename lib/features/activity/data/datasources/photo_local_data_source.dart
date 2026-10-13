import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/activity_photo.dart';
import '../../domain/services/uuid.dart';
import '../models/remote_activity_summary.dart';
import 'app_database.dart';
import '../../../../core/sync/device_owner.dart';

/// A local photo the server has not seen yet.
class PendingPhoto {
  const PendingPhoto({
    required this.id,
    required this.activityId,
    required this.path,
    required this.takenAt,
  });

  final String id;
  final String activityId;
  final String path;
  final DateTime takenAt;
}

/// Photo rows (`activity_photos`) plus their image files under [_dir].
/// Files are named by photo id, so signed URLs that change on every
/// listing never cause a re-download.
class PhotoLocalDataSource {
  PhotoLocalDataSource(this._db, this._dir);

  final Database _db;
  final Directory _dir;

  static const _photos = AppDatabase.photosTable;
  static const _activities = AppDatabase.activitiesTable;

  Future<List<ActivityPhoto>> photosOf(String activityId) async {
    final rows = await _db.query(
      _photos,
      where: 'activity_id = ? AND deleted_at IS NULL',
      whereArgs: [activityId],
      orderBy: 'taken_at',
    );
    return rows.map(_fromRow).toList();
  }

  Future<ActivityPhoto> addLocal({
    required String activityId,
    required List<int> bytes,
    required DateTime takenAt,
    required String? ownerId,
  }) async {
    final id = uuidV4();
    final file = await _write(id, bytes);
    await _db.insert(_photos, {
      'id': id,
      'activity_id': activityId,
      'owner_id': ownerId,
      'local_path': file.path,
      'taken_at': takenAt.millisecondsSinceEpoch,
      'synced': 0,
    });
    return ActivityPhoto(
      id: id,
      activityId: activityId,
      takenAt: takenAt,
      localPath: file.path,
    );
  }

  /// Never-uploaded photos go at once; uploaded ones keep a tombstone until
  /// the server delete succeeds. The file is removed either way.
  Future<void> markDeleted(String id) async {
    final rows = await _db.query(_photos, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    await _deleteFile(rows.first['local_path'] as String?);
    if (rows.first['synced'] == 1) {
      await _db.update(
        _photos,
        {
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
          'local_path': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await _db.delete(_photos, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Drops every photo of an activity (it was deleted; the server removes
  /// its photos itself).
  Future<void> removeAllOf(String activityId) async {
    final rows = await _db.query(
      _photos,
      columns: ['local_path'],
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
    for (final r in rows) {
      await _deleteFile(r['local_path'] as String?);
    }
    await _db.delete(
      _photos,
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
  }

  /// See ActivityLocalDataSource.parkUnowned.
  Future<void> parkUnowned() => _db.update(_photos, {
    'owner_id': kDeviceOnlyOwner,
  }, where: 'owner_id IS NULL');

  Future<void> restoreDeviceOnly() => _db.update(
    _photos,
    {'owner_id': null},
    where: 'owner_id = ?',
    whereArgs: [kDeviceOnlyOwner],
  );

  Future<void> claimUnowned(String ownerId) =>
      _db.update(_photos, {'owner_id': ownerId}, where: 'owner_id IS NULL');

  /// Uploads only for activities the server already has (synced rows).
  Future<List<PendingPhoto>> pendingUploads(String ownerId) async {
    final rows = await _db.rawQuery(
      'SELECT p.* FROM $_photos p JOIN $_activities a ON a.id = p.activity_id '
      'WHERE p.synced = 0 AND p.deleted_at IS NULL AND p.owner_id = ? '
      'AND a.synced = 1 AND p.local_path IS NOT NULL',
      [ownerId],
    );
    return [
      for (final r in rows)
        PendingPhoto(
          id: r['id']! as String,
          activityId: r['activity_id']! as String,
          path: r['local_path']! as String,
          takenAt: DateTime.fromMillisecondsSinceEpoch(r['taken_at']! as int),
        ),
    ];
  }

  Future<List<(String activityId, String photoId)>> pendingDeletes(
    String ownerId,
  ) async {
    final rows = await _db.query(
      _photos,
      columns: ['id', 'activity_id'],
      where: 'deleted_at IS NOT NULL AND owner_id = ?',
      whereArgs: [ownerId],
    );
    return [
      for (final r in rows) (r['activity_id']! as String, r['id']! as String),
    ];
  }

  Future<void> markUploaded(String id) =>
      _db.update(_photos, {'synced': 1}, where: 'id = ?', whereArgs: [id]);

  Future<void> purge(String id) async {
    final rows = await _db.query(_photos, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    await _deleteFile(rows.first['local_path'] as String?);
    await _db.delete(_photos, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> staleActivities(String ownerId) async {
    final rows = await _db.query(
      _activities,
      columns: ['id'],
      where: 'photos_stale = 1 AND owner_id = ? AND deleted_at IS NULL',
      whereArgs: [ownerId],
    );
    return [for (final r in rows) r['id']! as String];
  }

  /// Makes the local photos of [activityId] match the server [remote] list:
  /// downloads new ones, drops ones deleted elsewhere, keeps local pending
  /// uploads and tombstones. Returns whether anything changed.
  Future<bool> reconcile(
    String activityId,
    List<RemotePhoto> remote, {
    required String ownerId,
    required Future<List<int>> Function(Uri url) download,
  }) async {
    final local = {
      for (final r in await _db.query(
        _photos,
        where: 'activity_id = ?',
        whereArgs: [activityId],
      ))
        r['id']! as String: r,
    };
    var changed = false;
    final remoteIds = {for (final p in remote) p.id};
    for (final p in remote) {
      if (local.containsKey(p.id)) continue;
      final file = await _write(p.id, await download(p.url));
      await _db.insert(_photos, {
        'id': p.id,
        'activity_id': activityId,
        'owner_id': ownerId,
        'local_path': file.path,
        'taken_at': p.takenAt.millisecondsSinceEpoch,
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
    }
    for (final entry in local.entries) {
      final row = entry.value;
      final gone =
          row['synced'] == 1 &&
          row['deleted_at'] == null &&
          !remoteIds.contains(entry.key);
      if (gone) {
        await purge(entry.key);
        changed = true;
      }
    }
    await _db.update(
      _activities,
      {'photos_stale': 0},
      where: 'id = ?',
      whereArgs: [activityId],
    );
    return changed;
  }

  /// Removes photos whose activity no longer exists on this device.
  Future<void> pruneOrphans() async {
    final rows = await _db.rawQuery(
      'SELECT id, local_path FROM $_photos WHERE activity_id NOT IN '
      '(SELECT id FROM $_activities)',
    );
    for (final r in rows) {
      await _deleteFile(r['local_path'] as String?);
      await _db.delete(_photos, where: 'id = ?', whereArgs: [r['id']]);
    }
  }

  Future<File> _write(String id, List<int> bytes) async {
    await _dir.create(recursive: true);
    final file = File('${_dir.path}/$id.${imageExtension(bytes)}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } on PathNotFoundException {
      // Already gone (e.g. removed by a concurrent sync).
    }
  }

  static ActivityPhoto _fromRow(Map<String, Object?> r) => ActivityPhoto(
    id: r['id']! as String,
    activityId: r['activity_id']! as String,
    takenAt: DateTime.fromMillisecondsSinceEpoch(r['taken_at']! as int),
    localPath: r['local_path'] as String?,
  );
}

/// File extension from the image's magic bytes (the server checks the same
/// way): jpg, png or heic.
String imageExtension(List<int> bytes) {
  if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
  if (bytes.length > 11 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
      const [
        'heic',
        'heix',
        'mif1',
        'msf1',
        'hevc',
      ].contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return 'heic';
  }
  return 'jpg';
}
