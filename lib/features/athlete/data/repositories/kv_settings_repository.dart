import '../../../../core/storage/kv_store.dart';
import '../../../../core/units/distance_unit.dart';
import '../../domain/repositories/settings_repository.dart';

/// Device preferences in the `kv` table.
class KvSettingsRepository implements SettingsRepository {
  KvSettingsRepository(this._kv);

  static const _key = 'settings';

  final KvStore _kv;

  @override
  Future<DistanceUnit> distanceUnit() async {
    final json = await _kv.read(_key);
    return DistanceUnit.values.asNameMap()[json?['distanceUnit']] ??
        DistanceUnit.km;
  }

  @override
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    final json = await _kv.read(_key) ?? {};
    await _kv.write(_key, {...json, 'distanceUnit': unit.name});
  }
}
