import 'package:sqflite/sqflite.dart';

import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/app_database.dart';
import '../models/activity_row_mapper.dart';

class SqfliteActivityRepository implements ActivityRepository {
  SqfliteActivityRepository(this._db);

  final Database _db;

  @override
  Future<void> save(Activity activity) {
    return _db.transaction((txn) async {
      await txn.insert(
        AppDatabase.activitiesTable,
        ActivityRowMapper.activityToRow(activity),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        AppDatabase.trackPointsTable,
        where: 'activity_id = ?',
        whereArgs: [activity.id],
      );
      final batch = txn.batch();
      for (final row in ActivityRowMapper.pointsToRows(activity)) {
        batch.insert(AppDatabase.trackPointsTable, row);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<ActivitySummary>> getAll() async {
    final rows = await _db.query(
      AppDatabase.activitiesTable,
      orderBy: 'started_at DESC',
    );
    return rows.map(ActivityRowMapper.summaryFromRow).toList();
  }

  @override
  Future<Activity?> getById(String id) async {
    final rows = await _db.query(
      AppDatabase.activitiesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final points = await _db.query(
      AppDatabase.trackPointsTable,
      where: 'activity_id = ?',
      whereArgs: [id],
      orderBy: 'segment, seq',
    );
    return ActivityRowMapper.activityFromRows(rows.first, points);
  }

  @override
  Future<void> delete(String id) {
    return _db.transaction((txn) async {
      await txn.delete(
        AppDatabase.trackPointsTable,
        where: 'activity_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        AppDatabase.activitiesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
