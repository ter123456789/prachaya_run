import '../../../../core/units/distance_unit.dart';

/// Device preferences (not synced).
abstract interface class SettingsRepository {
  Future<DistanceUnit> distanceUnit();

  Future<void> setDistanceUnit(DistanceUnit unit);
}
