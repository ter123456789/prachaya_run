import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/data/repositories/http_challenge_repository.dart';
import 'package:prachaya_run/features/activity/data/services/open_meteo_weather_service.dart';
import 'package:prachaya_run/features/activity/domain/entities/weather_report.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_server.dart';
import '../../../helpers/memory_token_store.dart';

void main() {
  sqfliteFfiInit();
  late KvStore kv;
  late FakeServer server;
  late MemoryTokenStore tokens;
  late ApiClient api;

  setUp(() async {
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    kv = KvStore(db);
    server = FakeServer();
    tokens = MemoryTokenStore(
      const StoredSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        userId: 'u1',
        email: 'a@b.co',
      ),
    );
    api = ApiClient(
      baseUrl: 'http://api.test',
      tokens: tokens,
      httpClient: server.client,
    );
  });

  group('challenge', () {
    test('server challenge, cached for offline use', () async {
      final repo = HttpChallengeRepository(
        api,
        tokens,
        kv,
        clock: () => DateTime.utc(2026, 10, 11),
      );
      final c = (await repo.current())!;
      expect(c.badge, 'Night Owl');
      expect(c.goalMeters, 20000);
      expect(c.contains(DateTime.utc(2026, 9, 30, 17)), isTrue);
      expect(c.contains(DateTime.utc(2026, 10, 31, 17)), isFalse);

      server.offline = true;
      expect((await repo.current())!.badge, 'Night Owl');
    });

    test('signed out or stale cache → built-in for this month', () async {
      tokens.session = null;
      final repo = HttpChallengeRepository(
        api,
        tokens,
        kv,
        clock: () => DateTime(2026, 11, 3),
      );
      final c = (await repo.current())!;
      expect(c.id, '2026-11');
      expect(c.title, contains('พฤศจิกายน'));
      expect(c.goalMeters, HttpChallengeRepository.defaultGoalMeters);
    });
  });

  group('weather (Open-Meteo)', () {
    test('current conditions, cached', () async {
      var calls = 0;
      final service = OpenMeteoWeatherService(
        MockClient((r) async {
          calls++;
          expect(r.url.host, 'api.open-meteo.com');
          expect(r.url.queryParameters['current'], contains('weather_code'));
          return http.Response(
            jsonEncode({
              'current': {
                'temperature_2m': 27.4,
                'weather_code': 3,
                'wind_speed_10m': 5.2,
                'is_day': 0,
              },
            }),
            200,
          );
        }),
        kv,
      );
      final w = (await service.current(lat: 13.73, lng: 100.54))!;
      expect(w.temperatureC, 27.4);
      expect(w.kind, WeatherKind.cloudy);
      expect(w.isNight, isTrue);
      await service.current(lat: 13.73, lng: 100.54);
      expect(calls, 1);
    });

    test('conditions at a past hour pick the matching UTC hour', () async {
      final service = OpenMeteoWeatherService(
        MockClient((r) async {
          expect(r.url.queryParameters['timezone'], 'GMT');
          return http.Response(
            jsonEncode({
              'hourly': {
                'time': ['2026-10-08T22:00', '2026-10-08T23:00'],
                'temperature_2m': [25.0, 24.0],
                'weather_code': [61, 0],
                'wind_speed_10m': [3, 4],
                'is_day': [0, 0],
              },
            }),
            200,
          );
        }),
        kv,
      );
      final w = (await service.at(
        lat: 13.7,
        lng: 100.5,
        time: DateTime.utc(2026, 10, 8, 22, 40),
      ))!;
      expect(w.temperatureC, 25);
      expect(w.kind, WeatherKind.rain);
    });

    test('failures return null, never throw', () async {
      final service = OpenMeteoWeatherService(
        MockClient((_) async => throw http.ClientException('offline')),
        kv,
      );
      expect(await service.current(lat: 1, lng: 2), isNull);
    });
  });
}
