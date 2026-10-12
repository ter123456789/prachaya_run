import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/services/uuid.dart';

abstract final class AppDatabase {
  static const activitiesTable = 'activities';
  static const trackPointsTable = 'track_points';
  static const syncStateTable = 'sync_state';
  static const photosTable = 'activity_photos';
  static const kvTable = 'kv';
  static const shoesTable = 'shoes';
  static const workoutsTable = 'planned_workouts';
  static const version = 4;

  /// [factory] and [path] let tests use an in-memory FFI database.
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    return dbFactory.openDatabase(
      path ?? p.join(await dbFactory.getDatabasesPath(), 'prachaya_run.db'),
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createV1(db);
          await _upgradeToV2(db);
          await _upgradeToV3(db);
          await _upgradeToV4(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _upgradeToV2(db);
          if (oldVersion < 3) await _upgradeToV3(db);
          if (oldVersion < 4) await _upgradeToV4(db);
        },
      ),
    );
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE $activitiesTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        moving_time_ms INTEGER NOT NULL,
        distance_m REAL NOT NULL,
        elevation_gain_m REAL NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE $trackPointsTable (
        activity_id TEXT NOT NULL
          REFERENCES $activitiesTable(id) ON DELETE CASCADE,
        segment INTEGER NOT NULL,
        seq INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        timestamp INTEGER NOT NULL,
        PRIMARY KEY (activity_id, segment, seq)
      )''');
    await db.execute(
      'CREATE INDEX idx_activities_started_at '
      'ON $activitiesTable(started_at DESC)',
    );
  }

  /// v2 adds server sync:
  /// - `updated_at`: last local edit (ms), used for last-write-wins.
  /// - `deleted_at`: tombstone kept until the delete reaches the server.
  /// - `synced`: 0 while the row has changes the server has not seen.
  /// - `has_track`: 0 for activities pulled from another device whose GPS
  ///   track is downloaded only when opened.
  /// - `owner_id`: the account the activity belongs to. NULL for activities
  ///   recorded while signed out; the next account to sign in claims them.
  /// Old ids (timestamps) become UUIDs, as the server requires.
  static Future<void> _upgradeToV2(Database db) async {
    await db.execute(
      'ALTER TABLE $activitiesTable '
      'ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $activitiesTable ADD COLUMN deleted_at INTEGER',
    );
    await db.execute(
      'ALTER TABLE $activitiesTable '
      'ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $activitiesTable '
      'ADD COLUMN has_track INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute('ALTER TABLE $activitiesTable ADD COLUMN owner_id TEXT');
    await db.execute('UPDATE $activitiesTable SET updated_at = ended_at');
    await db.execute('''
      CREATE TABLE $syncStateTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');

    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    );
    final rows = await db.query(activitiesTable);
    for (final row in rows) {
      final oldId = row['id']! as String;
      if (uuidPattern.hasMatch(oldId)) continue;
      final newId = uuidV4();
      // Copy, repoint the track, then drop the old row (FKs stay valid).
      await db.insert(activitiesTable, {...row, 'id': newId});
      await db.update(
        trackPointsTable,
        {'activity_id': newId},
        where: 'activity_id = ?',
        whereArgs: [oldId],
      );
      await db.delete(activitiesTable, where: 'id = ?', whereArgs: [oldId]);
    }
  }

  /// v3 (redesign):
  /// - `activity_photos`: post-run photos, synced like activities
  ///   (`synced`, `deleted_at` tombstones, `owner_id`). Files live on disk at
  ///   `local_path`; NULL until a photo from another device is downloaded.
  /// - `activities.photo_count`: the server's count; `photos_stale` = 1 when
  ///   the photo list must be fetched again.
  /// - `kv`: small cached JSON (profile, challenge, weather).
  static Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
      CREATE TABLE $photosTable (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        owner_id TEXT,
        local_path TEXT,
        taken_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )''');
    await db.execute(
      'CREATE INDEX idx_photos_activity ON $photosTable(activity_id)',
    );
    await db.execute(
      'ALTER TABLE $activitiesTable '
      'ADD COLUMN photo_count INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $activitiesTable '
      'ADD COLUMN photos_stale INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('''
      CREATE TABLE $kvTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
  }

  /// v4 (athlete profile + training):
  /// - `activities.shoe_id`: the shoe an activity counts toward.
  /// - `shoes`, `planned_workouts`: synced like activities (`owner_id`,
  ///   `updated_at` last-write-wins, `deleted_at` tombstones, `synced`).
  ///   `data` holds the API JSON without the bookkeeping fields.
  /// The profile itself lives in `kv` (`profile:<account>` /
  /// `profile:local`).
  static Future<void> _upgradeToV4(Database db) async {
    await db.execute('ALTER TABLE $activitiesTable ADD COLUMN shoe_id TEXT');
    for (final table in [shoesTable, workoutsTable]) {
      await db.execute('''
        CREATE TABLE $table (
          id TEXT PRIMARY KEY,
          owner_id TEXT,
          data TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          synced INTEGER NOT NULL DEFAULT 0
        )''');
      await db.execute('CREATE INDEX idx_${table}_owner ON $table(owner_id)');
    }
  }
}
