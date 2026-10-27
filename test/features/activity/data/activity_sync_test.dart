import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/activity_local_data_source.dart';
import 'package:prachaya_run/features/activity/data/datasources/activity_remote_data_source.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/data/datasources/photo_local_data_source.dart';
import 'package:prachaya_run/features/activity/data/models/activity_json_mapper.dart';
import 'package:prachaya_run/features/activity/data/repositories/offline_first_activity_repository.dart';
import 'package:prachaya_run/features/activity/data/repositories/offline_first_photo_repository.dart';
import 'package:prachaya_run/features/activity/data/sync/activity_sync_engine.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/heart_rate.dart';
import 'package:prachaya_run/features/activity/domain/services/activity_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_server.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/memory_token_store.dart';

const _id = '3f2b8c1e-9d4a-4b7e-8f21-6c0d5e9a1b23';

Activity _activity({
  String id = _id,
  String title = 'วิ่งตอนเช้า',
  HeartRateTrack? heartRate,
}) {
  final a = sampleActivity();
  return Activity(
    id: id,
    type: a.type,
    title: title,
    startedAt: a.startedAt,
    endedAt: a.endedAt,
    movingTime: a.movingTime,
    segments: a.segments,
    heartRate: heartRate,
  );
}

void main() {
  sqfliteFfiInit();

  late FakeServer server;
  late MemoryTokenStore tokens;
  late ActivitySyncEngine engine;
  late OfflineFirstActivityRepository repository;
  late DateTime now;
  late ActivityLocalDataSource local;
  late Directory photoDir;
  late PhotoLocalDataSource photos;

  setUp(() async {
    server = FakeServer();
    tokens = MemoryTokenStore(
      const StoredSession(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        userId: 'u1',
        email: 'a@b.co',
      ),
    );
    final db = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokens: tokens,
      httpClient: server.client,
    );
    local = ActivityLocalDataSource(db);
    photoDir = Directory.systemTemp.createTempSync('photos');
    addTearDown(() => photoDir.deleteSync(recursive: true));
    photos = PhotoLocalDataSource(db, photoDir);
    engine = ActivitySyncEngine(
      local: local,
      remote: ActivityRemoteDataSource(api),
      photos: photos,
      tokens: tokens,
    );
    // Let syncs scheduled by saves finish before the database closes.
    addTearDown(() => engine.sync());
    now = DateTime(2026, 10, 11, 8);
    repository = OfflineFirstActivityRepository(
      local,
      engine,
      tokens,
      photos: photos,
      clock: () => now,
    );
  });

  test('a saved activity is uploaded gzipped and marked synced', () async {
    await repository.save(_activity());
    expect(await engine.sync(), SyncOutcome.synced);

    final post = server.requests.firstWhere((r) => r.method == 'POST');
    expect(post.headers['Content-Encoding'], 'gzip');
    expect(server.uploads.single['updatedAt'], ActivityJsonMapper.time(now));
    expect(server.activities[_id]!['title'], 'วิ่งตอนเช้า');

    // Nothing left to push on the next run.
    server.requests.clear();
    await engine.sync();
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    // Server totals are adopted.
    expect((await repository.getAll()).single.distanceMeters, 1000);
  });

  test('works offline and uploads once the server is back', () async {
    server.offline = true;
    await repository.save(_activity());
    expect(await engine.sync(), SyncOutcome.offline);
    expect(await repository.getAll(), hasLength(1));

    server.offline = false;
    expect(await engine.sync(), SyncOutcome.synced);
    expect(server.activities, contains(_id));
  });

  test(
    'a delete is sent to the server, then the tombstone is purged',
    () async {
      await repository.save(_activity());
      await engine.sync();

      await repository.delete(_id);
      expect(await repository.getAll(), isEmpty);
      expect(await engine.sync(), SyncOutcome.synced);

      expect(server.activities[_id]!['deletedAt'], isNotNull);
      expect(await repository.getById(_id), isNull);
    },
  );

  test(
    'pulls activities from other devices; track loads when opened',
    () async {
      const otherId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
      server.seed(
        ActivityJsonMapper.activityToJson(
          _activity(id: otherId, title: 'จากมือถืออีกเครื่อง'),
          updatedAt: now,
        ),
      );
      final changes = <void>[];
      final sub = engine.changes.listen(changes.add);
      addTearDown(sub.cancel);

      expect(await engine.sync(), SyncOutcome.synced);
      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(1));

      final summaries = await repository.getAll();
      expect(summaries.single.title, 'จากมือถืออีกเครื่อง');

      server.requests.clear();
      final full = await repository.getById(otherId);
      expect(full!.segments, _activity().segments);
      expect(server.requests.single.url.path, '/activities/$otherId');

      // Second open is served from the device.
      server.requests.clear();
      await repository.getById(otherId);
      expect(server.requests, isEmpty);

      // Deleted elsewhere → disappears here on the next pull.
      server.softDelete(otherId);
      await engine.sync();
      expect(await repository.getAll(), isEmpty);
    },
  );

  test('heart rate goes up with the activity and comes back with the track '
      'on another device (v1.5)', () async {
    await repository.save(_activity(heartRate: sampleHeartRate()));
    expect((await repository.getById(_id))!.heartRate, sampleHeartRate());
    await engine.sync();
    final sent = server.uploads.single['heartRate']! as Map<String, Object?>;
    expect(sent['source'], 'ble');
    expect((sent['samples']! as List).first, {'t': 5000, 'bpm': 128});

    // Another device: the feed has no heart rate; opening loads it.
    const otherId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
    server.seed(
      ActivityJsonMapper.activityToJson(
        _activity(id: otherId, heartRate: sampleHeartRate()),
        updatedAt: now,
      ),
    );
    await engine.sync();
    final full = await repository.getById(otherId);
    expect(full!.heartRate, sampleHeartRate());
  });

  test('server copy newer than the upload wins', () async {
    await repository.save(_activity());
    server.seed(
      ActivityJsonMapper.activityToJson(
        _activity(title: 'แก้จากเครื่องอื่น'),
        updatedAt: now.add(const Duration(minutes: 5)),
      ),
    );

    await engine.sync();
    expect((await repository.getAll()).single.title, 'แก้จากเครื่องอื่น');
  });

  test(
    'an expired access token is refreshed once and the call retried',
    () async {
      server.validAccessToken = 'access-new';
      server.validRefreshToken = 'refresh-1';
      // The refresh issues yet another token pair, which the retry uses.
      await repository.save(_activity());
      expect(await engine.sync(), SyncOutcome.synced);
      expect(
        server.requests.where((r) => r.url.path == '/auth/refresh'),
        hasLength(1),
      );
      expect(tokens.session!.refreshToken, server.validRefreshToken);
    },
  );

  test('parallel expired calls refresh only once', () async {
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokens: tokens,
      httpClient: server.client,
    );
    server.validAccessToken = 'access-new';
    await Future.wait([
      api.get('/activities', query: {'updatedSince': '1970'}),
      api.get('/activities', query: {'updatedSince': '1970'}),
      api.get('/activities', query: {'updatedSince': '1970'}),
    ]);
    expect(
      server.requests.where((r) => r.url.path == '/auth/refresh'),
      hasLength(1),
    );
    expect(tokens.session!.accessToken, server.validAccessToken);
  });

  test('a rejected refresh token signs out', () async {
    server.validAccessToken = 'access-new';
    server.validRefreshToken = 'something-else';
    await repository.save(_activity());

    final session = tokens.session;
    expect(await engine.sync(), SyncOutcome.signedOut);
    expect(tokens.session, isNull);
    // Kept on the device, shown again when the account signs back in.
    expect(await repository.getAll(), isEmpty);
    tokens.session = session;
    expect(await repository.getAll(), hasLength(1));
  });

  test('signed out: nothing is sent', () async {
    tokens.session = null;
    await repository.save(_activity());
    expect(await engine.sync(), SyncOutcome.signedOut);
    expect(server.requests, isEmpty);
  });

  test('parallel sync calls share one run', () async {
    await repository.save(_activity());
    server.requests.clear();
    final results = await Future.wait([engine.sync(), engine.sync()]);
    expect(results, everyElement(SyncOutcome.synced));
    expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  group('activities are scoped by account', () {
    const u1 = StoredSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      userId: 'u1',
      email: 'a@b.co',
    );
    const u2 = StoredSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      userId: 'u2',
      email: 'c@d.co',
    );

    test('recorded signed out → claimed by the next account', () async {
      tokens.session = null;
      await repository.save(_activity());
      expect(await repository.getAll(), hasLength(1));

      tokens.session = u1;
      expect(await repository.getAll(), hasLength(1));
      // Sync alone never takes signed-out data (the user chooses: 07.1).
      await engine.sync();
      expect(server.activities, isNot(contains(_id)));
      await engine.claimGuestData('u1');
      await engine.sync();
      expect(server.activities, contains(_id));

      // Signed out again: u1's activity is hidden, not deleted.
      tokens.session = null;
      expect(await repository.getAll(), isEmpty);
      expect(await repository.getById(_id), isNull);

      // Another account does not see it either.
      tokens.session = u2;
      expect(await repository.getAll(), isEmpty);
      await repository.delete(_id); // not theirs: ignored

      tokens.session = u1;
      expect(await repository.getAll(), hasLength(1));
    });

    test("another account's sync never uploads u1's activity", () async {
      tokens.session = u1;
      server.offline = true;
      await repository.save(_activity());
      await engine.sync();

      tokens.session = u2;
      server.offline = false;
      await engine.sync();
      expect(server.uploads, isEmpty);
    });
  });

  group('photos', () {
    // Minimal JPEG / PNG headers are enough: the app sniffs magic bytes.
    const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6, 7, 8];
    const png = [0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4, 5, 6, 7, 8];

    late OfflineFirstPhotoRepository photoRepo;
    setUp(
      () => photoRepo = OfflineFirstPhotoRepository(photos, engine, tokens),
    );

    test('a photo is uploaded after its activity, then kept by id', () async {
      await repository.save(_activity());
      final photo = await photoRepo.add(_id, jpeg, takenAt: now);
      expect(photo.localPath, endsWith('${photo.id}.jpg'));
      expect(await engine.sync(), SyncOutcome.synced);

      expect(server.photos.keys, [photo.id]);
      final put = server.requests.lastWhere((r) => r.method == 'PUT');
      expect(put.url.path, '/activities/$_id/photos/${photo.id}');

      // Nothing re-uploaded on the next run.
      server.requests.clear();
      await engine.sync();
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(await photoRepo.photosOf(_id), [photo]);
    });

    test(
      'storage down (503): the photo stays queued and goes up later',
      () async {
        await repository.save(_activity());
        server.storageDown = true;
        final photo = await photoRepo.add(_id, jpeg, takenAt: now);
        // The activity syncs; the outcome reports the photo still waiting.
        expect(await engine.sync(), SyncOutcome.failed);
        expect(server.activities, contains(_id));
        expect(server.photos, isEmpty);
        expect(await photoRepo.photosOf(_id), [photo]);

        server.storageDown = false;
        expect(await engine.sync(), SyncOutcome.synced);
        expect(server.photos.keys, [photo.id]);
      },
    );

    test('photos added on another device are downloaded; deletes flow both '
        'ways', () async {
      await repository.save(_activity());
      await engine.sync();

      server.seedPhoto(_id, 'p-remote', png);
      expect(await engine.sync(), SyncOutcome.synced);
      var list = await photoRepo.photosOf(_id);
      expect(list.single.id, 'p-remote');
      expect(list.single.localPath, endsWith('p-remote.png'));
      expect(File(list.single.localPath!).readAsBytesSync(), png);

      // Deleted here → DELETE sent, gone on the server.
      await photoRepo.delete(list.single);
      expect(await photoRepo.photosOf(_id), isEmpty);
      await engine.sync();
      expect(server.photos, isEmpty);

      // Deleted elsewhere → removed here.
      server.seedPhoto(_id, 'p2', jpeg);
      await engine.sync();
      list = await photoRepo.photosOf(_id);
      expect(list.single.id, 'p2');
      server.photos.remove('p2');
      server.activities[_id]!['_serverUpdatedAt'] = 999;
      await engine.sync();
      expect(await photoRepo.photosOf(_id), isEmpty);
    });

    test('deleting an activity removes its photo files', () async {
      await repository.save(_activity());
      final photo = await photoRepo.add(_id, jpeg, takenAt: now);
      await repository.delete(_id);
      expect(File(photo.localPath!).existsSync(), isFalse);
      expect(await photoRepo.photosOf(_id), isEmpty);
    });
  });

  test('purgeOwner removes only that account\'s activities', () async {
    await repository.save(_activity());
    await engine.sync(); // claimed by u1
    tokens.session = null;
    await repository.save(
      _activity(id: '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d'),
    );
    await local.purgeOwner('u1');
    expect(await repository.getAll(), hasLength(1)); // the unclaimed one
  });
}
