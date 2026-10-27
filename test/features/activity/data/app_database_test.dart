import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/auth/data/sync/profile_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;

  test('v1 → v2 adds sync columns and turns old ids into UUIDs', () async {
    final dir = Directory.systemTemp.createTempSync('prachaya_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    // A v1 database as shipped before sync.
    final v1 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE activities (id TEXT PRIMARY KEY, type TEXT NOT NULL,
              title TEXT NOT NULL, started_at INTEGER NOT NULL,
              ended_at INTEGER NOT NULL, moving_time_ms INTEGER NOT NULL,
              distance_m REAL NOT NULL, elevation_gain_m REAL NOT NULL)''');
          await db.execute('''
            CREATE TABLE track_points (activity_id TEXT NOT NULL
                REFERENCES activities(id) ON DELETE CASCADE,
              segment INTEGER NOT NULL, seq INTEGER NOT NULL,
              lat REAL NOT NULL, lng REAL NOT NULL, altitude REAL,
              accuracy REAL, timestamp INTEGER NOT NULL,
              PRIMARY KEY (activity_id, segment, seq))''');
          await db.insert('activities', {
            'id': '1760000000000000',
            'type': 'run',
            'title': 'old',
            'started_at': 1000,
            'ended_at': 5000,
            'moving_time_ms': 4000,
            'distance_m': 100.0,
            'elevation_gain_m': 0.0,
          });
          for (var i = 0; i < 3; i++) {
            await db.insert('track_points', {
              'activity_id': '1760000000000000',
              'segment': 0,
              'seq': i,
              'lat': 13.7,
              'lng': 100.5,
              'timestamp': 1000 + i,
            });
          }
        },
      ),
    );
    await v1.close();

    final db = await AppDatabase.open(factory: factory, path: path);
    addTearDown(db.close);

    final rows = await db.query('activities');
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(
      row['id'],
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')),
    );
    expect(row['updated_at'], 5000);
    expect(row['synced'], 0);
    expect(row['has_track'], 1);
    expect(row['deleted_at'], isNull);
    expect(row['owner_id'], isNull); // claimed by the first sign-in

    final points = await db.query('track_points');
    expect(points, hasLength(3));
    expect(points.every((p) => p['activity_id'] == row['id']), isTrue);
  });

  test('v3 → v4 keeps every row and adds shoes and planned workouts', () async {
    final dir = Directory.systemTemp.createTempSync('prachaya_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    // Build a v3 database through the real v1–v3 migrations, then add data.
    final v3 = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE activities (id TEXT PRIMARY KEY, type TEXT NOT NULL,
              title TEXT NOT NULL, started_at INTEGER NOT NULL,
              ended_at INTEGER NOT NULL, moving_time_ms INTEGER NOT NULL,
              distance_m REAL NOT NULL, elevation_gain_m REAL NOT NULL,
              updated_at INTEGER NOT NULL DEFAULT 0, deleted_at INTEGER,
              synced INTEGER NOT NULL DEFAULT 0,
              has_track INTEGER NOT NULL DEFAULT 1, owner_id TEXT,
              photo_count INTEGER NOT NULL DEFAULT 0,
              photos_stale INTEGER NOT NULL DEFAULT 0)''');
          await db.execute('''
            CREATE TABLE track_points (activity_id TEXT NOT NULL
                REFERENCES activities(id) ON DELETE CASCADE,
              segment INTEGER NOT NULL, seq INTEGER NOT NULL,
              lat REAL NOT NULL, lng REAL NOT NULL, altitude REAL,
              accuracy REAL, timestamp INTEGER NOT NULL,
              PRIMARY KEY (activity_id, segment, seq))''');
          await db.execute(
            'CREATE TABLE sync_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute('''
            CREATE TABLE activity_photos (id TEXT PRIMARY KEY,
              activity_id TEXT NOT NULL, owner_id TEXT, local_path TEXT,
              taken_at INTEGER NOT NULL, synced INTEGER NOT NULL DEFAULT 0,
              deleted_at INTEGER)''');
          await db.execute(
            'CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('activities', {
            'id': '3f2b8c1e-9d4a-4b7e-8f21-6c0d5e9a1b23',
            'type': 'run',
            'title': 'v3 run',
            'started_at': 1000,
            'ended_at': 5000,
            'moving_time_ms': 4000,
            'distance_m': 2500.0,
            'elevation_gain_m': 3.0,
            'updated_at': 5000,
            'synced': 1,
            'owner_id': 'u1',
          });
          // A v3 profile cache (server copy, no bookkeeping fields).
          await db.insert('kv', {
            'key': 'profile:u1',
            'value':
                '{"id":"u1","email":"a@b.co","displayName":"ปราชญา",'
                '"weightKg":70}',
          });
        },
      ),
    );
    await v3.close();

    final db = await AppDatabase.open(factory: factory, path: path);
    addTearDown(db.close);

    final row = (await db.query('activities')).single;
    expect(row['title'], 'v3 run');
    expect(row['synced'], 1);
    expect(row['shoe_id'], isNull);
    expect(await db.query(AppDatabase.shoesTable), isEmpty);
    expect(await db.query(AppDatabase.workoutsTable), isEmpty);

    // The old profile cache still reads, as a clean server copy.
    final stored = await ProfileStore(KvStore(db)).read('u1');
    expect(stored!.profile.displayName, 'ปราชญา');
    expect(stored.profile.weightKg, 70);
    expect(stored.dirty, isFalse);
  });

  test('v4 → v5 keeps shoes and plans and adds planned routes', () async {
    final dir = Directory.systemTemp.createTempSync('prachaya_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    // A v4 database: open at v5 with the real migrations, then roll the
    // version back and drop the v5 table, as a v4 install would have it.
    final v5 = await AppDatabase.open(factory: factory, path: path);
    await v5.insert(AppDatabase.shoesTable, {
      'id': 's1',
      'owner_id': 'u1',
      'data': '{"name":"Pegasus"}',
      'updated_at': 1,
      'synced': 1,
    });
    await v5.execute('DROP TABLE ${AppDatabase.routesTable}');
    await v5.execute(
      'ALTER TABLE ${AppDatabase.activitiesTable} DROP COLUMN heart_rate',
    );
    await v5.setVersion(4);
    await v5.close();

    final db = await AppDatabase.open(factory: factory, path: path);
    addTearDown(db.close);
    expect(await db.getVersion(), AppDatabase.version);
    expect((await db.query(AppDatabase.shoesTable)).single['id'], 's1');
    expect(await db.query(AppDatabase.routesTable), isEmpty);
    await db.insert(AppDatabase.routesTable, {
      'id': 'r1',
      'owner_id': null,
      'data': '{}',
      'updated_at': 1,
    });
    expect((await db.query(AppDatabase.routesTable)).single['synced'], 0);
  });

  test('v5 → v6 keeps activities and adds an empty heart_rate', () async {
    final dir = Directory.systemTemp.createTempSync('prachaya_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/test.db';
    // A v5 database: the current schema without the v6 column.
    final current = await AppDatabase.open(factory: factory, path: path);
    await current.execute(
      'ALTER TABLE ${AppDatabase.activitiesTable} DROP COLUMN heart_rate',
    );
    await current.insert(AppDatabase.activitiesTable, {
      'id': 'a1',
      'type': 'run',
      'title': 'v5 run',
      'started_at': 0,
      'ended_at': 1000,
      'moving_time_ms': 1000,
      'distance_m': 100,
      'elevation_gain_m': 0,
    });
    await current.setVersion(5);
    await current.close();

    final db = await AppDatabase.open(factory: factory, path: path);
    addTearDown(db.close);
    expect(await db.getVersion(), 6);
    final row = (await db.query(AppDatabase.activitiesTable)).single;
    expect(row['title'], 'v5 run');
    expect(row.containsKey('heart_rate'), isTrue);
    expect(row['heart_rate'], isNull);
  });
}
