/// Distance unit chosen in the profile settings. Applies app-wide: every
/// distance, pace and speed on screen and on share images uses it.
enum DistanceUnit { km, mi }

const double kMetersPerKm = 1000;
const double kMetersPerMile = 1609.344;

extension DistanceUnitMath on DistanceUnit {
  double get meters => switch (this) {
    DistanceUnit.km => kMetersPerKm,
    DistanceUnit.mi => kMetersPerMile,
  };

  /// [m] meters in this unit.
  double fromMeters(double m) => m / meters;

  double toMeters(double value) => value * meters;

  /// Seconds per one unit at [speedMps]; null when standing still.
  double? secondsPerUnit(double speedMps) =>
      speedMps < 0.3 ? null : meters / speedMps;

  /// Units per hour at [speedMps].
  double perHour(double speedMps) => speedMps * 3600 / meters;

  /// Converts a pace in seconds per km into seconds per this unit.
  double paceFromPerKm(double secondsPerKm) =>
      secondsPerKm * meters / kMetersPerKm;
}
