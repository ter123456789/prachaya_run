import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_origin.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/heart_rate.dart';
import 'package:prachaya_run/features/activity/domain/entities/imported_workout.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/repositories/health_import_store.dart';
import 'package:prachaya_run/features/activity/domain/services/uuid.dart';
import 'package:prachaya_run/features/activity/domain/usecases/import_activities.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHealthSource health;
  late InMemoryActivityRepository repository;
  late InMemoryHealthImportStore store;
  late DateTime now;
  late List<Activity> savedHooks;

  setUp(() {
    health = FakeHealthSource();
    repository = InMemoryActivityRepository();
    store = InMemoryHealthImportStore(
      HealthImportSettings(
        enabled: true,
        since: t0.subtract(const Duration(days: 30)),
      ),
    );
    now = t0.add(const Duration(days: 1));
    savedHooks = [];
  });

  ImportActivities importer() => ImportActivities(
    health,
    repository,
    store,
    titleFor: (type, start) => 'title ${type.name}',
    defaultShoe: (type) async => type == ActivityType.ride ? null : 'shoe-1',
    onSaved: [(a) async => savedHooks.add(a)],
    clock: () => now,
  );

  ImportedWorkout workout(
    String id, {
    WorkoutKind kind = WorkoutKind.run,
    Duration startAfter = Duration.zero,
    Duration length = const Duration(minutes: 30),
    double? distance = 5000,
  }) {
    final start = t0.add(startAfter);
    return ImportedWorkout(
      source: 'health-connect',
      externalId: id,
      kind: kind,
      start: start,
      end: start.add(length),
      activeTime: length - const Duration(minutes: 1),
      distanceMeters: distance,
      app: 'Samsung Health',
      device: 'Galaxy Watch7',
    );
  }

  HeartRateSample hr(int seconds, int bpm) => HeartRateSample(
    timestamp: t0.add(Duration(seconds: seconds)),
    bpm: bpm,
  );

  test('nothing happens while turned off', () async {
    store.settings = const HealthImportSettings();
    health.stored.add(workout('w1'));
    expect((await importer()()).imported, 0);
    expect(repository.store, isEmpty);
  });

  test('imports a run with route and heart rate under a stable id', () async {
    health.stored.add(workout('w1'));
    health.details['w1'] = WorkoutDetail(
      route: [
        pointAt(0, secondsPerStep: 10),
        pointAt(1, secondsPerStep: 10),
        // 5 minutes later: a pause, so a second segment.
        TrackPoint(
          latitude: 13.71,
          longitude: 100.5,
          timestamp: t0.add(const Duration(minutes: 6)),
        ),
      ],
      heartRate: [hr(0, 120), hr(1, 125)],
    );

    final result = await importer()();
    expect(result.imported, 1);
    final a = repository.store.values.single;
    expect(a.id, uuidV5('health-connect:w1'));
    expect(a.title, 'title run');
    expect(a.segments.map((s) => s.length), [2, 1]);
    expect(a.movingTime, const Duration(minutes: 29));
    expect(a.heartRate!.source, HeartRateSource.health);
    expect(
      a.origin,
      const ActivityOrigin(
        OriginKind.health,
        app: 'Samsung Health',
        device: 'Galaxy Watch7',
      ),
    );
    expect(a.shoeId, 'shoe-1');
    expect(savedHooks.single.id, a.id);
    expect(store.settings.lastImported, 1);
    expect(store.settings.lastImportAt, now);

    // Run again: nothing new, the detail is not even read again.
    health.detailsRead.clear();
    expect((await importer()()).imported, 0);
    expect(repository.store, hasLength(1));
    expect(health.detailsRead, isEmpty);
  });

  test('without a route the watch distance is used', () async {
    health.stored.add(workout('w1', distance: 8000));
    await importer()();
    final a = repository.store.values.single;
    expect(a.hasTrack, isFalse);
    expect(a.distanceMeters, 8000);
    expect(a.summary.distanceMeters, 8000);
  });

  test('walks only when asked; other kinds map to run / ride / hike', () async {
    health.stored.addAll([
      workout('walk', kind: WorkoutKind.walk),
      workout(
        'ride',
        kind: WorkoutKind.ride,
        startAfter: const Duration(hours: 2),
      ),
    ]);
    await importer()();
    expect(repository.store.values.map((a) => a.type), [ActivityType.ride]);
    expect(repository.store.values.single.shoeId, isNull);

    store.settings = store.settings.copyWith(includeWalks: true, seen: {});
    await importer()();
    expect(
      repository.store.values.map((a) => a.type),
      containsAll([ActivityType.ride, ActivityType.hike]),
    );
  });

  test('a workout deleted after import does not come back', () async {
    health.stored.add(workout('w1'));
    await importer()();
    await repository.delete(uuidV5('health-connect:w1'));
    await importer()();
    expect(repository.store, isEmpty);
  });

  test('the same run recorded on the phone is not duplicated; it gets the '
      "watch's heart rate", () async {
    final phone = sampleActivity(); // t0 → t0 + 30 min, no heart rate
    repository.store[phone.id] = phone;
    health.stored.add(workout('w1', startAfter: const Duration(minutes: 2)));
    health.details['w1'] = WorkoutDetail(
      heartRate: [hr(200, 140), hr(201, 141)],
    );

    final result = await importer()();
    expect(result.imported, 0);
    expect(result.heartRateAdded, 1);
    expect(repository.store, hasLength(1));
    expect(repository.store[phone.id]!.heartRate!.samples, hasLength(2));
  });

  test('recent phone runs get heart rate from the health store, only while '
      'moving', () async {
    final phone = sampleActivity();
    repository.store[phone.id] = phone;
    // Moving: 0–4.5 min and 10–19 min; the gap between is a pause.
    health.heartRates.addAll([
      hr(60, 130),
      hr(120, 132),
      hr(400, 90),
      hr(700, 150),
    ]);

    final result = await importer()();
    expect(result.heartRateAdded, 1);
    expect(repository.store[phone.id]!.heartRate!.samples.map((s) => s.bpm), [
      130,
      132,
      150,
    ]);

    // Older than 48 h: left alone.
    now = t0.add(const Duration(days: 3));
    repository.store[phone.id] = phone;
    expect((await importer()()).heartRateAdded, 0);
  });

  test('later runs look back a week from the last import', () async {
    store.settings = store.settings.copyWith(
      lastImportAt: t0.add(const Duration(days: 10)),
    );
    now = t0.add(const Duration(days: 11));
    health.stored.addAll([
      workout('old'), // 10 days before the last import
      workout('late', startAfter: const Duration(days: 5)), // synced late
    ]);
    await importer()();
    expect(repository.store.keys, [uuidV5('health-connect:late')]);
  });

  test('overlapShare and splitAtGaps', () {
    final a = t0, b = t0.add(const Duration(minutes: 60));
    expect(overlapShare(a, b, a.add(const Duration(minutes: 30)), b), 1);
    expect(
      overlapShare(
        a,
        b,
        a.add(const Duration(minutes: 45)),
        b.add(const Duration(minutes: 45)),
      ),
      closeTo(0.25, 1e-9),
    );
    expect(overlapShare(a, b, b, b.add(const Duration(minutes: 5))), 0);
    expect(splitAtGaps(const [], const Duration(seconds: 60)), isEmpty);
  });
}
