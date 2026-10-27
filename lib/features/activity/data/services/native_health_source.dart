import 'package:flutter/services.dart';

import '../../domain/entities/heart_rate.dart';
import '../../domain/entities/imported_workout.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/services/health_source.dart';

/// Apple Health / Health Connect through our own platform code (no plugin),
/// like the heart-rate sensor: `ios/Runner/HealthBridge.swift` (HealthKit)
/// and `android/.../HealthBridge.kt` (Health Connect).
///
/// `prachaya/health` methods; times are epoch milliseconds:
/// - `availability` / `requestAccess` → granted | denied | unavailable |
///   needsUpdate
/// - `workouts {from, to}` → `[{id, source, kind, start, end, activeMs?,
///   distanceM?, elevationM?, app?, device?}]`; kind ∈ run | ride | hike |
///   walk (other sports and this app's own workouts are left out natively)
/// - `detail {id, source, start, end}` → `{route: [{lat, lng, alt?, acc?,
///   t}], heartRate: [{t, bpm}]}`
/// - `heartRate {from, to}` → `[{t, bpm}]`
class NativeHealthSource implements HealthSource {
  NativeHealthSource({
    MethodChannel channel = const MethodChannel('prachaya/health'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<HealthAccess> availability() => _access('availability');

  @override
  Future<HealthAccess> requestAccess() => _access('requestAccess');

  @override
  Future<List<ImportedWorkout>> workouts({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _list('workouts', _span(from, to));
    return [for (final w in raw) ?_workout(w)];
  }

  @override
  Future<WorkoutDetail> detail(ImportedWorkout w) async {
    final raw = await _invoke<Map<Object?, Object?>>('detail', {
      'id': w.externalId,
      'source': w.source,
      ..._span(w.start, w.end),
    });
    if (raw == null) return const WorkoutDetail();
    final route = (raw['route'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    final hr = (raw['heartRate'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>();
    return WorkoutDetail(
      route: [
        for (final p in route)
          TrackPoint(
            latitude: (p['lat']! as num).toDouble(),
            longitude: (p['lng']! as num).toDouble(),
            altitudeMeters: (p['alt'] as num?)?.toDouble(),
            accuracyMeters: (p['acc'] as num?)?.toDouble(),
            timestamp: _time(p['t']),
          ),
      ],
      heartRate: _samples(hr),
    );
  }

  @override
  Future<List<HeartRateSample>> heartRate({
    required DateTime from,
    required DateTime to,
  }) async => _samples(await _list('heartRate', _span(from, to)));

  ImportedWorkout? _workout(Map<Object?, Object?> w) {
    final kind = WorkoutKind.values.asNameMap()[w['kind']];
    if (kind == null) return null;
    final active = w['activeMs'] as num?;
    return ImportedWorkout(
      source: w['source']! as String,
      externalId: w['id']! as String,
      kind: kind,
      start: _time(w['start']),
      end: _time(w['end']),
      activeTime: active == null
          ? null
          : Duration(milliseconds: active.toInt()),
      distanceMeters: (w['distanceM'] as num?)?.toDouble(),
      elevationGainMeters: (w['elevationM'] as num?)?.toDouble(),
      app: appLabel(w['app'] as String?),
      device: w['device'] as String?,
    );
  }

  /// Health Connect names the writing app by package; HealthKit by name.
  static String? appLabel(String? app) => switch (app) {
    null || '' => null,
    'com.sec.android.app.shealth' => 'Samsung Health',
    'com.garmin.android.apps.connectmobile' => 'Garmin Connect',
    'com.huami.watch.hmwatchmanager' => 'Zepp',
    'com.mi.health' || 'com.xiaomi.wearable' => 'Mi Fitness',
    'com.fitbit.FitbitMobile' => 'Fitbit',
    'com.google.android.apps.fitness' => 'Google Fit',
    'com.huawei.health' => 'Huawei Health',
    'fi.polar.polarflow' => 'Polar Flow',
    'com.coros.coros' => 'COROS',
    'com.suunto.android' => 'Suunto',
    _ => app,
  };

  static List<HeartRateSample> _samples(List<Map<Object?, Object?>> raw) => [
    for (final s in raw)
      HeartRateSample(
        timestamp: _time(s['t']),
        bpm: (s['bpm']! as num).round(),
      ),
  ];

  static Map<String, Object> _span(DateTime from, DateTime to) => {
    'from': from.millisecondsSinceEpoch,
    'to': to.millisecondsSinceEpoch,
  };

  static DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms! as num).toInt());

  Future<HealthAccess> _access(String method) async {
    final answer = await _invoke<String>(method);
    return HealthAccess.values.asNameMap()[answer] ?? HealthAccess.unavailable;
  }

  Future<List<Map<Object?, Object?>>> _list(
    String method,
    Object? args,
  ) async => ((await _invoke<List<Object?>>(method, args)) ?? const [])
      .cast<Map<Object?, Object?>>();

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // not wired on this platform (desktop, tests)
    } on PlatformException {
      return null;
    }
  }
}
