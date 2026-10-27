import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/data/repositories/kv_health_import_store.dart';
import 'package:prachaya_run/features/activity/domain/repositories/health_import_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fakes.dart';

void main() {
  sqfliteFfiInit();

  test('settings round-trip through kv', () async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final store = KvHealthImportStore(KvStore(db));
    expect((await store.load()).enabled, isFalse);

    await store.save(
      HealthImportSettings(
        enabled: true,
        since: t0,
        includeWalks: true,
        lastImportAt: t0.add(const Duration(hours: 1)),
        lastImported: 2,
        seen: {'id-1': t0},
      ),
    );
    final back = await store.load();
    expect(back.enabled, isTrue);
    expect(back.since, t0);
    expect(back.includeWalks, isTrue);
    expect(back.lastImportAt, t0.add(const Duration(hours: 1)));
    expect(back.lastImported, 2);
    expect(back.seen, {'id-1': t0});
  });
}
