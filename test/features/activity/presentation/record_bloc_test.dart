import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/services/location_tracker.dart';
import 'package:prachaya_run/features/activity/domain/usecases/save_activity.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/record/record_bloc.dart';

import '../../../helpers/fakes.dart';

void main() {
  late FakeLocationTracker tracker;
  late InMemoryActivityRepository repository;
  late DateTime now;

  setUp(() {
    tracker = FakeLocationTracker();
    repository = InMemoryActivityRepository();
    now = t0;
  });

  RecordBloc buildBloc() => RecordBloc(
    locationTracker: tracker,
    saveActivity: SaveActivity(repository),
    clock: () => now,
    tickInterval: const Duration(hours: 1),
  );

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  blocTest<RecordBloc, RecordState>(
    'reports permission denied and stays idle',
    setUp: () => tracker.access = LocationAccess.deniedForever,
    build: buildBloc,
    act: (bloc) => bloc.add(const RecordStarted()),
    expect: () => [
      const RecordState(failure: RecordFailure.permissionDeniedForever),
    ],
  );

  blocTest<RecordBloc, RecordState>(
    'changing type is ignored while recording',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const RecordTypeChanged(ActivityType.ride));
      bloc.add(const RecordStarted());
      await pump();
      bloc.add(const RecordTypeChanged(ActivityType.hike));
    },
    verify: (bloc) {
      expect(bloc.state.type, ActivityType.ride);
      expect(bloc.state.status, RecordStatus.recording);
    },
  );

  test('records, pauses, resumes and saves an activity', () async {
    final bloc = buildBloc()..add(const RecordStarted());
    await pump();
    expect(bloc.state.status, RecordStatus.recording);

    for (var i = 0; i < 3; i++) {
      tracker.emit(pointAt(i));
    }
    await pump();
    expect(bloc.state.distanceMeters, closeTo(222.4, 0.5));

    now = t0.add(const Duration(minutes: 2));
    bloc.add(const RecordPaused());
    await pump();
    expect(bloc.state.status, RecordStatus.paused);
    expect(bloc.state.movingTime, const Duration(minutes: 2));

    now = t0.add(const Duration(minutes: 5));
    bloc.add(const RecordResumed());
    await pump();
    tracker.emit(pointAt(10));
    tracker.emit(pointAt(11));
    await pump();

    now = t0.add(const Duration(minutes: 6));
    bloc.add(const RecordFinished());
    await pump();

    expect(bloc.state.status, RecordStatus.saved);
    final saved = repository.store[bloc.state.savedActivityId]!;
    expect(saved.segments, hasLength(2));
    expect(saved.movingTime, const Duration(minutes: 3));
    expect(saved.title, 'วิ่งตอนเช้า');
    await bloc.close();
  });

  test('too-short activity stays paused with a failure', () async {
    final bloc = buildBloc()..add(const RecordStarted());
    await pump();
    tracker.emit(pointAt(0));
    await pump();
    bloc.add(const RecordFinished());
    await pump();

    expect(bloc.state.status, RecordStatus.paused);
    expect(bloc.state.failure, RecordFailure.tooShort);
    expect(repository.store, isEmpty);
    await bloc.close();
  });

  test('GPS error auto-pauses the recording', () async {
    final bloc = buildBloc()..add(const RecordStarted());
    await pump();
    tracker.fail();
    await pump();

    expect(bloc.state.status, RecordStatus.paused);
    expect(bloc.state.failure, RecordFailure.locationLost);
    await bloc.close();
  });
}
