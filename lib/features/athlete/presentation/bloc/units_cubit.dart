import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/units/distance_unit.dart';
import '../../domain/repositories/settings_repository.dart';

/// The app-wide distance unit (km / mi).
class UnitsCubit extends Cubit<DistanceUnit> {
  UnitsCubit(this._settings) : super(DistanceUnit.km);

  final SettingsRepository _settings;

  Future<void> load() async {
    final unit = await _settings.distanceUnit();
    if (!isClosed) emit(unit);
  }

  Future<void> set(DistanceUnit unit) async {
    emit(unit);
    await _settings.setDistanceUnit(unit);
  }
}
