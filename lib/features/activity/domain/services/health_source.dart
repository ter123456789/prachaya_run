import '../entities/heart_rate.dart';
import '../entities/imported_workout.dart';

enum HealthAccess {
  granted,
  denied,

  /// No Apple Health / Health Connect on this device.
  unavailable,

  /// Health Connect must be installed or updated first (Android).
  needsUpdate,
}

/// Port for the device's health store: Apple Health (iOS) or Health
/// Connect (Android).
abstract interface class HealthSource {
  Future<HealthAccess> availability();

  /// Shows the system permission screen.
  Future<HealthAccess> requestAccess();

  /// Running, cycling, hiking and walking workouts that started in
  /// [from]–[to], written by other apps (never this one).
  Future<List<ImportedWorkout>> workouts({
    required DateTime from,
    required DateTime to,
  });

  Future<WorkoutDetail> detail(ImportedWorkout workout);

  /// Heart rate from any source (a watch worn during a phone recording).
  Future<List<HeartRateSample>> heartRate({
    required DateTime from,
    required DateTime to,
  });
}
