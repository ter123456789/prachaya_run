import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/storage/kv_store.dart';
import '../../domain/entities/weather_report.dart';
import '../../domain/services/weather_service.dart';

/// Open-Meteo (free, no key). Past conditions are cached for good; the
/// current ones for 30 minutes.
class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService(this._http, this._kv);

  final http.Client _http;
  final KvStore _kv;

  static const _vars = 'temperature_2m,weather_code,wind_speed_10m,is_day';

  @override
  Future<WeatherReport?> current({
    required double lat,
    required double lng,
  }) async {
    final key =
        'weather:now:${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    final cached = await _kv.read(key);
    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - (cached['at']! as int) <
            30 * 60 * 1000) {
      return _fromCache(cached);
    }
    final json = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'current': _vars,
      }),
    );
    final current = json?['current'] as Map<String, Object?>?;
    if (current == null) return cached == null ? null : _fromCache(cached);
    final report = _report(
      current['temperature_2m'],
      current['weather_code'],
      current['wind_speed_10m'],
      current['is_day'],
    );
    await _kv.write(key, {
      ..._toCache(report),
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    return report;
  }

  @override
  Future<WeatherReport?> at({
    required double lat,
    required double lng,
    required DateTime time,
  }) async {
    final utc = time.toUtc();
    final hour = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    final key =
        'weather:${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}@'
        '${hour.toIso8601String()}';
    final cached = await _kv.read(key);
    if (cached != null) return _fromCache(cached);

    final recent = DateTime.now().toUtc().difference(hour).inDays < 80;
    final report = await _hourly(lat, lng, hour, archive: !recent);
    if (report == null) return null;
    await _kv.write(key, _toCache(report));
    return report;
  }

  @override
  Future<WeatherReport?> forecast({
    required double lat,
    required double lng,
    required DateTime time,
  }) {
    final utc = time.toUtc();
    // Forecasts change: fetched fresh every time, never cached.
    return _hourly(
      lat,
      lng,
      DateTime.utc(utc.year, utc.month, utc.day, utc.hour),
      archive: false,
    );
  }

  /// The hourly values at [hour] (UTC, whole hour).
  Future<WeatherReport?> _hourly(
    double lat,
    double lng,
    DateTime hour, {
    required bool archive,
  }) async {
    final day = hour.toIso8601String().substring(0, 10);
    final json = await _get(
      Uri.https(
        archive ? 'archive-api.open-meteo.com' : 'api.open-meteo.com',
        archive ? '/v1/archive' : '/v1/forecast',
        {
          'latitude': '$lat',
          'longitude': '$lng',
          'hourly': _vars,
          'start_date': day,
          'end_date': day,
          'timezone': 'GMT',
        },
      ),
    );
    final hourly = json?['hourly'] as Map<String, Object?>?;
    if (hourly == null) return null;
    final times = (hourly['time']! as List<Object?>).cast<String>();
    final i = times.indexWhere(
      (t) => DateTime.parse('${t}Z').isAtSameMomentAs(hour),
    );
    if (i < 0) return null;
    Object? v(String name) => (hourly[name] as List<Object?>?)?[i];
    if (v('temperature_2m') == null) return null;
    return _report(
      v('temperature_2m'),
      v('weather_code'),
      v('wind_speed_10m'),
      v('is_day'),
    );
  }

  Future<Map<String, Object?>?> _get(Uri url) async {
    try {
      final response = await _http
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, Object?>;
    } catch (_) {
      return null; // Weather is decoration: never fail a screen over it.
    }
  }

  static WeatherReport _report(
    Object? temp,
    Object? code,
    Object? wind,
    Object? isDay,
  ) => WeatherReport(
    temperatureC: (temp! as num).toDouble(),
    windKmh: (wind as num?)?.toDouble() ?? 0,
    kind: WeatherReport.kindFromWmo((code as num?)?.toInt() ?? 0),
    isNight: isDay == 0,
  );

  static Map<String, Object?> _toCache(WeatherReport r) => {
    't': r.temperatureC,
    'w': r.windKmh,
    'k': r.kind.name,
    'n': r.isNight,
  };

  static WeatherReport _fromCache(Map<String, Object?> j) => WeatherReport(
    temperatureC: (j['t']! as num).toDouble(),
    windKmh: (j['w']! as num).toDouble(),
    kind: WeatherKind.values.byName(j['k']! as String),
    isNight: j['n']! as bool,
  );
}
