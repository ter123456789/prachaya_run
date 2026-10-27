import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/imported_workout.dart';
import 'package:prachaya_run/features/activity/domain/services/health_source.dart';
import 'package:prachaya_run/features/activity/domain/usecases/import_activities.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/health_import/health_import_cubit.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeHealthSource health;
  late InMemoryHealthImportStore store;
  late InMemoryActivityRepository repository;
  final now = t0.add(const Duration(hours: 2));

  setUp(() {
    health = FakeHealthSource();
    store = InMemoryHealthImportStore();
    repository = InMemoryActivityRepository();
  });

  HealthImportCubit build() => HealthImportCubit(
    source: health,
    store: store,
    importer: ImportActivities(
      health,
      repository,
      store,
      titleFor: (_, _) => 'run',
      clock: () => now,
    ),
    clock: () => now,
  );

  test(
    'unavailable without a health store; hidden in tests without one',
    () async {
      final none = HealthImportCubit();
      await none.load();
      expect(none.state.available, isFalse);
      health.access = HealthAccess.unavailable;
      health.asked = true;
      final cubit = build();
      await cubit.load();
      expect(cubit.state.available, isFalse);
    },
  );

  test(
    'turning on asks, imports from the chosen range, counts new ones',
    () async {
      health.stored.add(
        ImportedWorkout(
          source: 'healthkit',
          externalId: 'w1',
          kind: WorkoutKind.run,
          start: t0,
          end: t0.add(const Duration(minutes: 30)),
          distanceMeters: 5000,
        ),
      );
      final cubit = build();
      final changes = <ImportResult>[];
      cubit.changes.listen(changes.add);
      await cubit.load();
      expect(cubit.state.available, isTrue);
      expect(cubit.state.enabled, isFalse);

      await cubit.enable(daysBack: 30);
      expect(health.asked, isTrue);
      expect(store.settings.enabled, isTrue);
      expect(store.settings.since, now.subtract(const Duration(days: 30)));
      expect(cubit.state.newActivities, 1);
      expect(cubit.state.lastImported, 1);
      expect(repository.store, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect(changes, hasLength(1));

      cubit.acknowledge();
      expect(cubit.state.newActivities, 0);
      await cubit.disable();
      expect(store.settings.enabled, isFalse);
    },
  );

  test('a refused permission leaves it off and says so', () async {
    health.access = HealthAccess.denied;
    final cubit = build();
    await cubit.load();
    await cubit.enable(daysBack: 0);
    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.failed, isTrue);
    expect(store.settings.enabled, isFalse);
  });
}
