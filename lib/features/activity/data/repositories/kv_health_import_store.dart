import '../../../../core/storage/kv_store.dart';
import '../../domain/repositories/health_import_store.dart';

/// Device setting in `kv` (`settings.health_import`), like the reminders.
class KvHealthImportStore implements HealthImportStore {
  KvHealthImportStore(this._kv);

  static const _key = 'settings.health_import';

  final KvStore _kv;

  @override
  Future<HealthImportSettings> load() async {
    final json = await _kv.read(_key);
    if (json == null) return const HealthImportSettings();
    DateTime? time(Object? ms) =>
        ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
    return HealthImportSettings(
      enabled: json['enabled'] == true,
      since: time(json['since']),
      includeWalks: json['includeWalks'] == true,
      lastImportAt: time(json['lastImportAt']),
      lastImported: json['lastImported'] as int? ?? 0,
      seen: {
        for (final e in ((json['seen'] as Map?) ?? const {}).entries)
          e.key as String: DateTime.fromMillisecondsSinceEpoch(e.value as int),
      },
    );
  }

  @override
  Future<void> save(HealthImportSettings s) => _kv.write(_key, {
    'enabled': s.enabled,
    'since': s.since?.millisecondsSinceEpoch,
    'includeWalks': s.includeWalks,
    'lastImportAt': s.lastImportAt?.millisecondsSinceEpoch,
    'lastImported': s.lastImported,
    'seen': {
      for (final e in s.seen.entries) e.key: e.value.millisecondsSinceEpoch,
    },
  });
}
