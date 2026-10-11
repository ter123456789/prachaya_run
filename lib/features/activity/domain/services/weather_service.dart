import '../entities/weather_report.dart';

abstract interface class WeatherService {
  /// Current conditions; null when unavailable (offline, no service).
  Future<WeatherReport?> current({required double lat, required double lng});

  /// Conditions at [time] (past ~3 months); null when unavailable.
  Future<WeatherReport?> at({
    required double lat,
    required double lng,
    required DateTime time,
  });
}
