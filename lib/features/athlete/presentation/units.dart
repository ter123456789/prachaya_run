import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatters.dart';
import '../../../core/units/distance_unit.dart';
import '../../../core/units/unit_labels.dart';
import 'bloc/units_cubit.dart';

/// Distances, paces and speeds in the unit chosen in the profile.
class UnitFormat {
  const UnitFormat(this.unit);

  final DistanceUnit unit;

  /// `5.32`
  String distance(double meters) => formatDistance(meters, unit);

  /// For count-up metrics.
  double distanceValue(double meters) => unit.fromMeters(meters);

  /// `กม.` / `ไมล์`
  String get distanceUnit => unit.short;

  /// `5:32`
  String pace(double speedMps) => formatPaceIn(speedMps, unit);

  /// `5'32"`
  String paceQuote(double speedMps) {
    final seconds = unit.secondsPerUnit(speedMps);
    return seconds == null ? "--'--\"" : formatPaceSecondsQuote(seconds);
  }

  /// A pace given in seconds per km, shown per [unit]: `5'15"`.
  String paceFromPerKm(int secondsPerKm) =>
      formatPaceSecondsQuote(unit.paceFromPerKm(secondsPerKm.toDouble()));

  /// `/กม.` / `/ไมล์`
  String get paceUnit => unit.paceSuffix;

  /// `11.9`
  String speed(double speedMps) => formatSpeedIn(speedMps, unit);

  /// `กม./ชม.` / `ไมล์/ชม.`
  String get speedUnit => unit.speed;

  /// Wind given in km/h, e.g. `12 กม./ชม.`.
  String windFromKmh(double kmh) =>
      '${(kmh * kMetersPerKm / unit.meters).round()} ${unit.speed}';
}

extension UnitsContext on BuildContext {
  /// The current unit; rebuilds the caller when it changes. Defaults to km
  /// where no [UnitsCubit] is provided (isolated widget tests).
  UnitFormat get units {
    try {
      return UnitFormat(watch<UnitsCubit>().state);
    } on ProviderNotFoundException {
      return const UnitFormat(DistanceUnit.km);
    }
  }
}
