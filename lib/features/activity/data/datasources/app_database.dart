import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract final class AppDatabase {
  static const activitiesTable = 'activities';
  static const trackPointsTable = 'track_points';

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'prachaya_run.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
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
      },
    );
  }
}
