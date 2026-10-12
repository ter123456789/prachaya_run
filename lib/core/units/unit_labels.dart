import 'distance_unit.dart';

/// On-screen unit names. Thai for copy, Latin for telemetry pills.
extension DistanceUnitLabels on DistanceUnit {
  /// `กม.` / `ไมล์`
  String get short => switch (this) {
    DistanceUnit.km => 'กม.',
    DistanceUnit.mi => 'ไมล์',
  };

  /// `กิโลเมตร` / `ไมล์`
  String get long => switch (this) {
    DistanceUnit.km => 'กิโลเมตร',
    DistanceUnit.mi => 'ไมล์',
  };

  /// `/กม.` / `/ไมล์`
  String get paceSuffix => '/$short';

  /// `กม./ชม.` / `ไมล์/ชม.`
  String get speed => switch (this) {
    DistanceUnit.km => 'กม./ชม.',
    DistanceUnit.mi => 'ไมล์/ชม.',
  };

  /// `KM` / `MI`
  String get latin => switch (this) {
    DistanceUnit.km => 'KM',
    DistanceUnit.mi => 'MI',
  };

  /// `KM/H` / `MPH`
  String get latinSpeed => switch (this) {
    DistanceUnit.km => 'KM/H',
    DistanceUnit.mi => 'MPH',
  };

  /// `/KM` / `/MI`
  String get latinPace => '/$latin';

  /// Share-image labels in English: `km` / `mi`.
  String get english => switch (this) {
    DistanceUnit.km => 'km',
    DistanceUnit.mi => 'mi',
  };

  String get englishSpeed => switch (this) {
    DistanceUnit.km => 'km/h',
    DistanceUnit.mi => 'mph',
  };
}
