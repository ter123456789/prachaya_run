import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/core/sync/record_sync_participant.dart';
import 'package:prachaya_run/core/sync/synced_record_store.dart';
import 'package:prachaya_run/features/activity/data/datasources/activity_local_data_source.dart';
import 'package:prachaya_run/features/activity/data/datasources/activity_remote_data_source.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/data/datasources/photo_local_data_source.dart';
import 'package:prachaya_run/features/activity/data/repositories/offline_first_activity_repository.dart';
import 'package:prachaya_run/features/activity/data/sync/activity_sync_engine.dart';
import 'package:prachaya_run/features/activity/data/sync/device_guest_data.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/athlete/data/repositories/offline_first_shoe_repository.dart';
import 'package:prachaya_run/features/athlete/domain/entities/shoe.dart';
import 'package:prachaya_run/features/auth/data/repositories/local_first_profile_repository.dart';
import 'package:prachaya_run/features/auth/data/sync/profile_store.dart';
import 'package:prachaya_run/features/auth/data/sync/profile_sync.dart';
import 'package:prachaya_run/features/auth/domain/entities/guest_data_summary.dart';
import 'package:prachaya_run/features/auth/domain/entities/user_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_server.dart';
import '../../../helpers/memory_token_store.dart';

const _runId = '3f2b8c1e-9d4a-4b7e-8f21-6c0d5e9a1b23';
const _shoeId = '0f9a7c3e-1d2b-4c5e-8f60-7a8b9c0d1e2f';

const _session = StoredSession(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  userId: 'u1',
  email: 'a@b.co',
);

/// A straight 6 km run at 3 m/s with a point every 10 s.
Activity _run() {
  final start = DateTime.utc(2026, 10, 10, 6);
  const metersPerDegree = 111195.0;
  final points = [
    for (var i = 0; i <= 200; i++)
      TrackPoint(
        latitude: 13.7 + i * 30 / metersPerDegree,
        longitude: 100.5,
        timestamp: start.add(Duration(seconds: i * 10)),
      ),
  ];
  return Activity(
    id: _runId,
    type: ActivityType.run,
    title: 'วิ่งตอนเช้า',
    startedAt: start,
    endedAt: start.add(const Duration(seconds: 2000)),
    movingTime: const Duration(seconds: 2000),
    segments: [points],
  );
}

void main() {
  sqfliteFfiInit();

  late FakeServer server;
  late MemoryTokenStore tokens;
  late ActivitySyncEngine engine;
  late OfflineFirstActivityRepository activities;
  late OfflineFirstShoeRepository shoes;
  late LocalFirstProfileRepository profile;
  late DeviceGuestData guest;

  setUp(() async {
    server = FakeServer();
    tokens = MemoryTokenStore();
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
    final photoDir = Directory.systemTemp.createTempSync('photos');
    addTearDown(() => photoDir.deleteSync(recursive: true));
    final profiles = ProfileStore(KvStore(db));
    final shoeStore = SyncedRecordStore(db, AppDatabase.shoesTable);
    final workoutStore = SyncedRecordStore(db, AppDatabase.workoutsTable);
    final local = ActivityLocalDataSource(db);
    final photos = PhotoLocalDataSource(db, photoDir);
    engine = ActivitySyncEngine(
      local: local,
      remote: ActivityRemoteDataSource(api),
      photos: photos,
      tokens: tokens,
      participants: [
        ProfileSync(profiles, api),
        RecordSyncParticipant(shoeStore, api, path: '/shoes'),
        RecordSyncParticipant(workoutStore, api, path: '/workouts'),
      ],
    );
    addTearDown(() => engine.sync());
    void schedule() {}
    activities = OfflineFirstActivityRepository(
      local,
      engine,
      tokens,
      photos: photos,
    );
    shoes = OfflineFirstShoeRepository(
      shoeStore,
      tokens,
      scheduleSync: schedule,
    );
    profile = LocalFirstProfileRepository(
      profiles,
      tokens,
      scheduleSync: schedule,
    );
    guest = DeviceGuestData(
      activities: local,
      photos: photos,
      shoes: shoeStore,
      workouts: workoutStore,
      profiles: profiles,
      sync: engine,
    );
  });

  Future<void> recordAsGuest() async {
    await activities.save(_run());
    await shoes.save(const Shoe(id: _shoeId, name: 'Pegasus', primary: true));
    await profile.save(const UserProfile(heightCm: 175));
  }

  test('empty device: nothing to ask about', () async {
    expect((await guest.summary()).isEmpty, isTrue);
  });

  test('summary counts what was recorded signed out, with PBs', () async {
    await recordAsGuest();
    final s = await guest.summary();
    expect(s.activityCount, 1);
    expect(s.distanceMeters, closeTo(6000, 5));
    expect(s.movingTime, const Duration(seconds: 2000));
    expect(s.shoeCount, 1);
    expect(s.workoutCount, 0);
    expect(s.hasProfile, isTrue);
    // 3 m/s → 5 km in 1666.7 s; no 10 km yet.
    expect(s.bests.fiveK!.inMilliseconds, closeTo(1666667, 2000));
    expect(s.bests.tenK, isNull);

    // An account's own data is not guest data.
    tokens.session = _session;
    await guest.merge('u1');
    expect(await guest.summary(), GuestDataSummary.empty);
  });

  test('merge gives everything to the account and uploads it', () async {
    await recordAsGuest();
    tokens.session = _session;
    await engine.sync();
    expect(server.activities, isEmpty, reason: 'sync alone never claims');

    await guest.merge('u1');
    await engine.sync();
    expect(server.activities, contains(_runId));
    expect(server.live('shoes').single['name'], 'Pegasus');
    expect(server.profile['heightCm'], 175);

    tokens.session = null;
    expect(await activities.getAll(), isEmpty, reason: "now the account's");
  });

  test('keep on device: hidden from the account, never sent, back on '
      'sign-out', () async {
    await recordAsGuest();
    tokens.session = _session;
    await guest.keepOnDevice();

    expect(await activities.getAll(), isEmpty);
    expect(await shoes.getAll(), isEmpty);
    expect((await profile.load()).heightCm, isNull);
    await engine.sync();
    expect(server.activities, isEmpty);
    expect(server.live('shoes'), isEmpty);
    expect(server.profile['heightCm'], isNull);
    expect(await guest.summary(), GuestDataSummary.empty);

    tokens.session = null;
    await guest.restore();
    expect(await activities.getAll(), hasLength(1));
    expect(await shoes.getAll(), hasLength(1));
    expect((await profile.load()).heightCm, 175);
    expect((await guest.summary()).activityCount, 1);
  });
}
