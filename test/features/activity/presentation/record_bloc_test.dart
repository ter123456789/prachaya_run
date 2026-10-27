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

  test('a lap restarts the lap distance and time', () async {
    final bloc = buildBloc()..add(const RecordStarted());
    await pump();
    tracker
      ..emit(pointAt(0))
      ..emit(pointAt(3));
    await pump();
    now = t0.add(const Duration(minutes: 2));
    bloc.add(const RecordLapped());
    await pump();
    expect(bloc.state.lapNumber, 2);
    expect(bloc.state.lapDistanceMeters, 0);
    expect(bloc.state.lapTime, Duration.zero);

    tracker.emit(pointAt(5));
    await pump();
    now = t0.add(const Duration(minutes: 3));
    bloc.add(const RecordPaused());
    await pump();
    expect(bloc.state.lapDistanceMeters, closeTo(222.4, 0.5));
    expect(bloc.state.lapTime, const Duration(minutes: 1));

    // Paused: the lap button does nothing.
    bloc.add(const RecordLapped());
    await pump();
    expect(bloc.state.lapNumber, 2);
    await bloc.close();
  });

  group('vehicle', () {
    DateTime at(int second) => t0.add(Duration(seconds: second));

    Future<void> drive(
      RecordBloc bloc,
      List<(int, double)> legs, {
      int startSecond = 0,
      double startMeters = 0,
    }) async {
      for (final fix in journey(
        legs,
        startSecond: startSecond,
        startMeters: startMeters,
      )) {
        now = fix.timestamp;
        tracker.emit(fix);
        await pump();
      }
    }

    test('a car ride is not counted and recording resumes after', () async {
      final bloc = buildBloc()..add(const RecordStarted());
      await pump();

      await drive(bloc, [(60, 3.5), (60, 15)]);
      expect(bloc.state.status, RecordStatus.paused);
      expect(bloc.state.inVehicle, isTrue);
      expect(bloc.state.distanceMeters, closeTo(59 * 3.5, 0.5));
      expect(bloc.state.movingTime, const Duration(seconds: 60));

      await drive(bloc, [(120, 3)], startSecond: 120, startMeters: 1110);
      expect(bloc.state.status, RecordStatus.recording);
      expect(bloc.state.inVehicle, isFalse);

      bloc.add(const RecordFinished());
      await pump();
      final saved = repository.store[bloc.state.savedActivityId]!;
      expect(saved.segments, hasLength(2));
      // Back from when the car stopped (its last fix at 2:00).
      expect(saved.segments.last.first.timestamp, at(120));
      expect(saved.distanceMeters, closeTo(59 * 3.5 + 120 * 3, 1));
      expect(saved.movingTime, const Duration(minutes: 3));
      await bloc.close();
    });

    test('"ทำต่อ" in a vehicle overrides it until a new ride shows', () async {
      final bloc = buildBloc()..add(const RecordStarted());
      await pump();
      await drive(bloc, [(60, 3.5), (30, 15)]);
      expect(bloc.state.inVehicle, isTrue);

      bloc.add(const RecordResumed());
      await pump();
      expect(bloc.state.status, RecordStatus.recording);
      expect(bloc.state.inVehicle, isFalse);
      expect(tracker.controller!.hasListener, isTrue);

      await drive(bloc, [(30, 15)], startSecond: 90, startMeters: 660);
      expect(bloc.state.inVehicle, isTrue);
      await bloc.close();
    });

    test('GPS loss in a vehicle leaves an ordinary pause', () async {
      final bloc = buildBloc()..add(const RecordStarted());
      await pump();
      await drive(bloc, [(60, 3.5), (30, 15)]);
      tracker.fail();
      await pump();
      expect(bloc.state.status, RecordStatus.paused);
      expect(bloc.state.inVehicle, isFalse);
      expect(bloc.state.failure, RecordFailure.locationLost);
      await bloc.close();
    });
  });
}
