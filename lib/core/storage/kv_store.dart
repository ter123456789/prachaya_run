import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Tiny JSON cache in the app database's `kv` table.
class KvStore {
  KvStore(this._db, {this.table = 'kv'});

  final Database _db;
  final String table;

  Future<Map<String, Object?>?> read(String key) async {
    final rows = await _db.query(
      table,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value']! as String) as Map<String, Object?>;
  }

  Future<void> write(String key, Map<String, Object?> value) => _db.insert(
    table,
    {'key': key, 'value': jsonEncode(value)},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> remove(String key) =>
      _db.delete(table, where: 'key = ?', whereArgs: [key]);
}
