enum WeatherKind { clear, cloudy, fog, drizzle, rain, storm }

/// Conditions at a place and time.
class WeatherReport {
  const WeatherReport({
    required this.temperatureC,
    required this.windKmh,
    required this.kind,
    required this.isNight,
  });

  final double temperatureC;
  final double windKmh;
  final WeatherKind kind;
  final bool isNight;

  /// WMO weather interpretation code → [WeatherKind].
  static WeatherKind kindFromWmo(int code) => switch (code) {
    0 || 1 => WeatherKind.clear,
    2 || 3 => WeatherKind.cloudy,
    45 || 48 => WeatherKind.fog,
    >= 51 && <= 57 => WeatherKind.drizzle,
    >= 95 => WeatherKind.storm,
    _ => WeatherKind.rain,
  };
}

/// How the weather suits a run, for the dashboard tip.
enum RunAdvice { great, hot, veryHot, wet, windy }

RunAdvice adviseRun(WeatherReport w) {
  if (w.kind == WeatherKind.storm ||
      w.kind == WeatherKind.rain ||
      w.kind == WeatherKind.drizzle) {
    return RunAdvice.wet;
  }
  if (w.temperatureC >= 33) return RunAdvice.veryHot;
  if (w.temperatureC >= 29) return RunAdvice.hot;
  if (w.windKmh >= 30) return RunAdvice.windy;
  return RunAdvice.great;
}
