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
import 'package:prachaya_run/features/activity/data/repositories/offline_first_photo_repository.dart';
import 'package:prachaya_run/features/activity/data/sync/activity_sync_engine.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/services/activity_sync.dart';
import 'package:prachaya_run/features/athlete/data/repositories/offline_first_shoe_repository.dart';
import 'package:prachaya_run/features/athlete/domain/entities/shoe.dart';
import 'package:prachaya_run/features/auth/data/repositories/local_first_profile_repository.dart';
import 'package:prachaya_run/features/auth/data/sync/profile_store.dart';
import 'package:prachaya_run/features/auth/data/sync/profile_sync.dart';
import 'package:prachaya_run/features/auth/domain/entities/user_profile.dart';
import 'package:prachaya_run/features/auth/domain/services/profile_validation.dart';
import 'package:prachaya_run/features/training/data/repositories/offline_first_workout_repository.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/fake_server.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/memory_token_store.dart';

const _shoeId = '0f9a7c3e-1d2b-4c5e-8f60-7a8b9c0d1e2f';
const _shoe2 = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
const _workoutId = '9e8d7c6b-5a49-4382-9170-6f5e4d3c2b1a';
const _activityId = '3f2b8c1e-9d4a-4b7e-8f21-6c0d5e9a1b23';

const _session = StoredSession(
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  userId: 'u1',
  email: 'a@b.co',
);

void main() {
  sqfliteFfiInit();

  late FakeServer server;
  late MemoryTokenStore tokens;
  late ActivitySyncEngine engine;
  late OfflineFirstShoeRepository shoes;
  late OfflineFirstWorkoutRepository workouts;
  late LocalFirstProfileRepository profile;
  late OfflineFirstActivityRepository activities;
  late SyncedRecordStore shoeStore;
  late PhotoLocalDataSource photoStore;
  late DateTime now;

  setUp(() async {
    server = FakeServer();
    tokens = MemoryTokenStore(_session);
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
    now = DateTime(2026, 10, 12, 8);
    final profiles = ProfileStore(KvStore(db));
    shoeStore = SyncedRecordStore(db, AppDatabase.shoesTable);
    final workoutStore = SyncedRecordStore(db, AppDatabase.workoutsTable);
    final local = ActivityLocalDataSource(db);
    engine = ActivitySyncEngine(
      local: local,
      remote: ActivityRemoteDataSource(api),
      photos: photoStore = PhotoLocalDataSource(db, photoDir),
      tokens: tokens,
      participants: [
        ProfileSync(profiles, api, clock: () => now),
        RecordSyncParticipant(shoeStore, api, path: '/shoes'),
        RecordSyncParticipant(workoutStore, api, path: '/workouts'),
      ],
    );
    addTearDown(() => engine.sync());
    void schedule() {}
    shoes = OfflineFirstShoeRepository(
      shoeStore,
      tokens,
      scheduleSync: schedule,
      clock: () => now,
    );
    workouts = OfflineFirstWorkoutRepository(
      workoutStore,
      tokens,
      scheduleSync: schedule,
      clock: () => now,
    );
    profile = LocalFirstProfileRepository(
      profiles,
      tokens,
      scheduleSync: schedule,
      clock: () => now,
    );
    activities = OfflineFirstActivityRepository(
      local,
      engine,
      tokens,
      photos: photoStore,
      clock: () => now,
    );
  });

  Activity sampleRun() {
    final a = sampleActivity();
    return Activity(
      id: _activityId,
      type: a.type,
      title: a.title,
      startedAt: a.startedAt,
      endedAt: a.endedAt,
      movingTime: a.movingTime,
      segments: a.segments,
    );
  }

  void tick([Duration by = const Duration(minutes: 1)]) => now = now.add(by);

  PlannedWorkout workout({String title = 'Tempo Run'}) => PlannedWorkout(
    id: _workoutId,
    type: WorkoutType.tempo,
    title: title,
    location: 'สวนลุมพินี',
    scheduledAt: DateTime(2026, 10, 14, 18, 30),
    distanceMeters: 7000,
    paceMinSecPerKm: 315,
    paceMaxSecPerKm: 330,
  );

  group('shoes and workouts', () {
    test('made signed out, claimed and uploaded once on sign-in', () async {
      tokens.session = null;
      await shoes.save(const Shoe(id: _shoeId, name: 'Pegasus', primary: true));
      await workouts.save(workout());
      expect(await shoes.getAll(), hasLength(1));
      expect(await engine.pendingCount(), 2);
      expect(await engine.sync(), SyncOutcome.signedOut);
      expect(server.requests, isEmpty);

      tokens.session = _session;
      await engine.claimGuestData('u1');
      expect(await engine.sync(), SyncOutcome.synced);
      expect(server.live('shoes').single['name'], 'Pegasus');
      final w = server.live('workouts').single;
      expect(w['type'], 'tempo');
      expect(w['scheduledAt'], '2026-10-14T11:30:00.000Z');
      expect(w['paceMinSecPerKm'], 315);
      expect(await engine.pendingCount(), 0);
      expect((await shoeStore.get(_shoeId))!.ownerId, 'u1');

      server.requests.clear();
      await engine.sync();
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    test('works offline and uploads when back', () async {
      server.offline = true;
      await shoes.save(const Shoe(id: _shoeId, name: 'Pegasus'));
      expect(await engine.sync(), SyncOutcome.offline);
      expect(await shoes.getAll(), hasLength(1));
      server.offline = false;
      expect(await engine.sync(), SyncOutcome.synced);
      expect(server.live('shoes'), hasLength(1));
    });

    test('pulls records made on another device, without duplicates', () async {
      server.seedRecord('workouts', {
        'id': _workoutId,
        'type': 'easy',
        'title': 'Easy from phone 2',
        'location': null,
        'scheduledAt': '2026-10-15T00:00:00.000Z',
        'distanceM': 5000,
        'paceMinSecPerKm': 390,
        'paceMaxSecPerKm': 420,
        'completedActivityId': null,
        'updatedAt': '2026-10-12T00:00:00.000Z',
      });
      await engine.sync();
      await engine.sync();
      final all = await workouts.getAll();
      expect(all, hasLength(1));
      expect(all.single.title, 'Easy from phone 2');
      expect(all.single.scheduledAt, DateTime.utc(2026, 10, 15).toLocal());
    });

    test('a newer local edit wins; a newer server edit is adopted', () async {
      await workouts.save(workout());
      await engine.sync();

      // Another device edits it later.
      server.records['workouts']![_workoutId]!
        ..['title'] = 'Edited on phone 2'
        ..['updatedAt'] = '2026-10-13T00:00:00.000Z'
        ..['_serverUpdatedAt'] = 999;
      await engine.sync();
      expect((await workouts.getAll()).single.title, 'Edited on phone 2');

      // An edit made here even later wins and is uploaded.
      now = DateTime(2026, 10, 14);
      await workouts.save(workout(title: 'Edited here'));
      await engine.sync();
      expect(server.live('workouts').single['title'], 'Edited here');
      expect((await workouts.getAll()).single.title, 'Edited here');
    });

    test('an older local edit loses to the server copy', () async {
      server.seedRecord('shoes', {
        'id': _shoeId,
        'name': 'Server name',
        'model': null,
        'lifespanKm': 600,
        'startDistanceM': 0,
        'primary': false,
        'retired': false,
        'updatedAt': '2026-10-20T00:00:00.000Z',
      });
      // Edited offline before the server's version, then pushed.
      await shoes.save(const Shoe(id: _shoeId, name: 'Old local name'));
      await engine.sync();
      expect((await shoes.getAll()).single.name, 'Server name');
      expect(server.live('shoes').single['name'], 'Server name');
    });

    test('deletes go up as tombstones and come down from others', () async {
      await shoes.save(const Shoe(id: _shoeId, name: 'Pegasus'));
      await workouts.save(workout());
      await engine.sync();

      await shoes.delete(_shoeId);
      expect(await shoes.getAll(), isEmpty);
      await engine.sync();
      expect(server.live('shoes'), isEmpty);
      expect(await shoeStore.get(_shoeId), isNull); // tombstone purged

      server.records['workouts']![_workoutId]!
        ..['deletedAt'] = '2026-10-12T09:00:00.000Z'
        ..['_serverUpdatedAt'] = 999;
      await engine.sync();
      expect(await workouts.getAll(), isEmpty);
    });

    test('two devices can each set a primary: the latest edit wins', () async {
      server.seedRecord('shoes', {
        'id': _shoe2,
        'name': 'Set primary on phone 2',
        'model': null,
        'lifespanKm': 600,
        'startDistanceM': 0,
        'primary': true,
        'retired': false,
        'updatedAt': '2026-10-12T00:30:00.000Z',
      });
      now = DateTime.utc(2026, 10, 12, 0, 10);
      await shoes.save(const Shoe(id: _shoeId, name: 'Here', primary: true));
      await engine.sync();
      final all = await shoes.getAll();
      expect(all.where((s) => s.primary).map((s) => s.id), [_shoe2]);
      expect((await shoes.primary())!.id, _shoe2);

      // Saving a primary here unsets the other one locally.
      now = DateTime.utc(2026, 10, 12, 1);
      await shoes.save(const Shoe(id: _shoeId, name: 'Here', primary: true));
      expect((await shoes.primary())!.id, _shoeId);
      await engine.sync();
      expect(
        server.live('shoes').where((s) => s['primary'] == true).single['id'],
        _shoeId,
      );
    });

    test('photo storage down does not hold back shoes and plans', () async {
      final photoRepo = OfflineFirstPhotoRepository(photoStore, engine, tokens);
      await activities.save(sampleRun());
      await photoRepo.add(_activityId, const [
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        1,
        2,
        3,
        4,
      ], takenAt: now);
      await shoes.save(const Shoe(id: _shoeId, name: 'Pegasus'));
      await workouts.save(workout());
      server.storageDown = true;
      expect(await engine.sync(), SyncOutcome.failed);
      expect(server.live('shoes'), hasLength(1));
      expect(server.live('workouts'), hasLength(1));
      expect(server.photos, isEmpty);

      server.storageDown = false;
      expect(await engine.sync(), SyncOutcome.synced);
      expect(server.photos, hasLength(1));
    });

    test('invalid records are rejected before they are stored', () async {
      expect(
        () => shoes.save(const Shoe(id: _shoeId, name: '')),
        throwsA(isA<ShoeValidationException>()),
      );
      expect(
        () => workouts.save(workout(title: '   ')),
        throwsA(isA<WorkoutValidationException>()),
      );
      expect(await engine.pendingCount(), 0);
    });

    test("another account's records stay hidden", () async {
      await shoes.save(const Shoe(id: _shoeId, name: 'Mine'));
      tokens.session = const StoredSession(
        accessToken: 'x',
        refreshToken: 'y',
        userId: 'u2',
        email: 'c@d.co',
      );
      expect(await shoes.getAll(), isEmpty);
      await shoes.delete(_shoeId); // not theirs: ignored
      tokens.session = _session;
      expect(await shoes.getAll(), hasLength(1));
    });
  });

  group('profile', () {
    test('saved on the device while signed out', () async {
      tokens.session = null;
      final saved = await profile.save(
        const UserProfile(
          displayName: '  ปราชญา ',
          weightKg: 64.5,
          heightCm: 175,
          birthYear: 2002,
        ),
      );
      expect(saved.displayName, 'ปราชญา');
      expect((await profile.load()).heightCm, 175);
      expect(await engine.pendingCount(), 1);
    });

    test('on sign-in it fills the account profile and is pushed', () async {
      server.profile = {
        ...server.profile,
        'displayName': 'Server name',
        'weightKg': 70,
      };
      tokens.session = null;
      await profile.save(const UserProfile(heightCm: 175, birthYear: 2002));

      tokens.session = _session;
      // Shown merged straight away, before any sync.
      final shown = await profile.load();
      expect(shown.heightCm, 175);

      await engine.claimGuestData('u1');
      await engine.sync();
      expect(server.profile['heightCm'], 175);
      expect(server.profile['birthYear'], 2002);
      final p = await profile.load();
      expect(p.heightCm, 175);
      expect(p.birthYear, 2002);
      expect(await engine.pendingCount(), 0);
    });

    test(
      'edits push every field (so clearing one reaches the server)',
      () async {
        await profile.save(const UserProfile(weightKg: 60, maxHrBpm: 190));
        await engine.sync();
        expect(server.profile['maxHrBpm'], 190);

        tick();
        await profile.save(const UserProfile(weightKg: 60));
        await engine.sync();
        expect(server.profile.containsKey('maxHrBpm'), isTrue);
        expect(server.profile['maxHrBpm'], isNull);
      },
    );

    test('pulls changes made elsewhere when there is no local edit', () async {
      server.profile = {...server.profile, 'birthYear': 1990, 'maxHrBpm': 185};
      await engine.sync();
      final p = await profile.load();
      expect(p.birthYear, 1990);
      expect(p.maxHrBpm, 185);
    });

    test('out-of-range values are rejected', () async {
      expect(
        () => profile.save(const UserProfile(maxHrBpm: 250, heightCm: 90)),
        throwsA(
          isA<ProfileValidationException>().having((e) => e.fields, 'fields', {
            ProfileField.maxHrBpm,
            ProfileField.heightCm,
          }),
        ),
      );
    });
  });

  group('activity shoe link', () {
    Activity run({String? shoe}) {
      final a = sampleActivity();
      return Activity(
        id: _activityId,
        type: a.type,
        title: a.title,
        startedAt: a.startedAt,
        endedAt: a.endedAt,
        movingTime: a.movingTime,
        segments: a.segments,
        shoeId: shoe,
      );
    }

    test('uploaded with the activity, kept on pull, editable', () async {
      await activities.save(run(shoe: _shoeId));
      await engine.sync();
      expect(server.uploads.last['shoeId'], _shoeId);
      expect((await activities.getAll()).single.shoeId, _shoeId);

      tick();
      await activities.setShoe(_activityId, null);
      expect(await engine.pendingCount(), 1);
      await engine.sync();
      expect(server.uploads.last.containsKey('shoeId'), isTrue);
      expect(server.uploads.last['shoeId'], isNull);
    });

    test('a shoe set on another device arrives with the summary', () async {
      server.seed({...ActivityRemoteSeed.json(_activityId), 'shoeId': _shoe2});
      await engine.sync();
      expect((await activities.getAll()).single.shoeId, _shoe2);
    });
  });
}

/// A minimal activity as another device would upload it.
abstract final class ActivityRemoteSeed {
  static Map<String, Object?> json(String id) => {
    'id': id,
    'type': 'run',
    'title': 'From phone 2',
    'startedAt': '2026-10-11T00:00:00.000Z',
    'endedAt': '2026-10-11T00:30:00.000Z',
    'movingTimeMs': 1800000,
    'updatedAt': '2026-10-11T00:30:00.000Z',
    'segments': [
      [
        {
          'lat': 13.7,
          'lng': 100.5,
          'altitude': null,
          'accuracy': null,
          'timestamp': '2026-10-11T00:00:00.000Z',
        },
      ],
    ],
  };
}
