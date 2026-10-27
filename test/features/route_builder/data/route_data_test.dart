import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/core/sync/record_sync_participant.dart';
import 'package:prachaya_run/core/sync/synced_record_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/route_builder/data/models/polyline_codec.dart';
import 'package:prachaya_run/features/route_builder/data/models/route_json_mapper.dart';
import 'package:prachaya_run/features/route_builder/data/repositories/offline_first_route_repository.dart';
import 'package:prachaya_run/features/route_builder/data/services/http_route_snapper.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/planned_route.dart';
import 'package:prachaya_run/features/route_builder/domain/repositories/route_snapper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_server.dart';
import '../../../helpers/memory_token_store.dart';

const _session = StoredSession(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  userId: 'u1',
  email: 'a@b.co',
);

const _heart = PlannedRoute(
  id: '5b1e3d7a-2c4f-4a8b-9e6d-1f0a2b3c4d5e',
  name: 'หัวใจ',
  drawn: [GeoPoint(13.73, 100.54), GeoPoint(13.74, 100.55)],
  route: [
    GeoPoint(13.73, 100.54),
    GeoPoint(13.735, 100.545),
    GeoPoint(13.74, 100.55),
  ],
  closed: true,
  distanceMeters: 1580.5,
  score: 87,
);

void main() {
  sqfliteFfiInit();

  group('PolylineCodec', () {
    test("matches Google's worked example", () {
      const points = [
        GeoPoint(38.5, -120.2),
        GeoPoint(40.7, -120.95),
        GeoPoint(43.252, -126.453),
      ];
      expect(PolylineCodec.encode(points), r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(PolylineCodec.decode(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@'), points);
    });

    test('round-trips to 1e-5 degrees and rejects junk', () {
      const p = [GeoPoint(13.731234, 100.541239), GeoPoint(-33.9, 151.2)];
      final back = PolylineCodec.decode(PolylineCodec.encode(p));
      expect(back[0].latitude, closeTo(13.73123, 1e-9));
      expect(back[1].longitude, closeTo(151.2, 1e-9));
      expect(PolylineCodec.decode(''), isEmpty);
      expect(() => PolylineCodec.decode('_p~iF'), throwsFormatException);
      expect(() => PolylineCodec.decode('ab cd'), throwsFormatException);
    });
  });

  test('RouteJsonMapper round-trips, unsnapped too', () {
    final back = RouteJsonMapper.fromJson(
      _heart.id,
      RouteJsonMapper.toJson(_heart),
    );
    expect(back.name, 'หัวใจ');
    expect(back.drawn, _heart.drawn);
    expect(back.route, _heart.route);
    expect(back.closed, isTrue);
    expect(back.distanceMeters, 1580.5);
    expect(back.score, 87);

    const raw = PlannedRoute(
      id: 'x',
      name: 'ร่าง',
      drawn: [GeoPoint(13.73, 100.54), GeoPoint(13.74, 100.55)],
      distanceMeters: 1500,
    );
    final json = RouteJsonMapper.toJson(raw);
    expect(json['route'], isNull);
    expect(json['score'], isNull);
    expect(RouteJsonMapper.fromJson('x', json).isSnapped, isFalse);
  });

  group('with the fake server', () {
    late FakeServer server;
    late MemoryTokenStore tokens;
    late ApiClient api;
    late OfflineFirstRouteRepository repo;
    late RecordSyncParticipant sync;

    setUp(() async {
      server = FakeServer();
      tokens = MemoryTokenStore();
      final db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      api = ApiClient(
        baseUrl: 'http://api.test',
        tokens: tokens,
        httpClient: server.client,
      );
      final store = SyncedRecordStore(db, AppDatabase.routesTable);
      repo = OfflineFirstRouteRepository(store, tokens, scheduleSync: () {});
      sync = RecordSyncParticipant(store, api, path: '/routes');
    });

    test('saves on the device, pushes, and pulls a delete', () async {
      tokens.session = _session;
      await repo.save(_heart.copyWith(name: '  หัวใจ  '));
      expect((await repo.getAll()).single.name, 'หัวใจ');

      await sync.sync('u1');
      final sent = server.live('routes').single;
      expect(sent['name'], 'หัวใจ');
      expect(PolylineCodec.decode(sent['route']! as String), _heart.route);
      expect(sent['score'], 87);

      await repo.delete(_heart.id);
      expect(await repo.getAll(), isEmpty);
      await sync.sync('u1');
      expect(server.live('routes'), isEmpty);
    });

    test('rejects an empty name or a one-point drawing', () async {
      expect(
        () => repo.save(_heart.copyWith(name: ' ')),
        throwsA(isA<RouteValidationException>()),
      );
      expect(
        () => repo.save(
          const PlannedRoute(
            id: 'x',
            name: 'จุด',
            drawn: [GeoPoint(13.73, 100.54)],
            distanceMeters: 0,
          ),
        ),
        throwsA(isA<RouteValidationException>()),
      );
    });

    test('HttpRouteSnapper sends the shape and reads the route', () async {
      tokens.session = _session;
      final snapped = await HttpRouteSnapper(api).snap(_heart.drawn);
      expect(snapped.points, _heart.drawn); // the fake echoes the shape
      expect(snapped.distanceMeters, 1000);
    });

    test('HttpRouteSnapper maps failures', () async {
      Future<RouteSnapError> errorOf() async {
        try {
          await HttpRouteSnapper(api).snap(_heart.drawn);
        } on RouteSnapException catch (e) {
          return e.error;
        }
        fail('no error');
      }

      expect(await errorOf(), RouteSnapError.signedOut);
      tokens.session = _session;
      server.offline = true;
      expect(await errorOf(), RouteSnapError.unavailable);
    });
  });
}
