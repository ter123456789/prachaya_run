import '../entities/activity_type.dart';

/// Body weight used when the user has not set one in their profile.
const double kDefaultWeightKg = 65;

/// Rough energy estimate in kcal from MET values (Compendium of Physical
/// Activities). Running uses the speed-independent ~1 kcal/kg/km rule;
/// cycling METs rise with speed; hiking uses MET 6.
double estimateCalories({
  required ActivityType type,
  required double distanceMeters,
  required Duration movingTime,
  double? weightKg,
}) {
  final kg = weightKg ?? kDefaultWeightKg;
  final hours = movingTime.inSeconds / 3600;
  if (hours <= 0) return 0;
  switch (type) {
    case ActivityType.run:
      return kg * distanceMeters / 1000 * 1.036;
    case ActivityType.ride:
      final kmh = distanceMeters / 1000 / hours;
      final met = kmh < 16
          ? 4.0
          : kmh < 19
          ? 6.8
          : kmh < 22
          ? 8.0
          : kmh < 25
          ? 10.0
          : 12.0;
      return met * kg * hours;
    case ActivityType.hike:
      return 6.0 * kg * hours;
  }
}
