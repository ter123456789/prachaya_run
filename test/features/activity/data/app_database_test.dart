import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
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
}
