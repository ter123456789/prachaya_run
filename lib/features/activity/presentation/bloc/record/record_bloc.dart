import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity_type.dart';
import '../../../domain/entities/recording_session.dart';
import '../../../domain/entities/track_point.dart';
import '../../../domain/services/location_tracker.dart';
import '../../../domain/services/vehicle_detector.dart';
import '../../../domain/usecases/save_activity.dart';
import '../../activity_labels.dart';

part 'record_event.dart';
part 'record_state.dart';

class RecordBloc extends Bloc<RecordEvent, RecordState> {
  RecordBloc({
    required LocationTracker locationTracker,
    required SaveActivity saveActivity,
    DateTime Function()? clock,
    this.tickInterval = const Duration(seconds: 1),
  }) : _tracker = locationTracker,
       _saveActivity = saveActivity,
       _clock = clock ?? DateTime.now,
       super(const RecordState()) {
    on<RecordTypeChanged>(_onTypeChanged);
    on<RecordStarted>(_onStarted);
    on<RecordPaused>(_onPaused);
    on<RecordResumed>(_onResumed);
    on<RecordLapped>(_onLapped);
    on<RecordFinished>(_onFinished);
    on<RecordReset>(_onReset);
    on<_LocationReceived>(_onLocationReceived);
    on<_LocationFailed>(_onLocationFailed);
    on<_Ticked>(_onTicked);
  }

  final LocationTracker _tracker;
  final SaveActivity _saveActivity;
  final DateTime Function() _clock;
  final Duration tickInterval;

  RecordingSession? _session;
  VehicleDetector? _vehicle;
  StreamSubscription<TrackPoint>? _locationSub;
  StreamSubscription<void>? _tickerSub;

  void _onTypeChanged(RecordTypeChanged event, Emitter<RecordState> emit) {
    if (state.status != RecordStatus.idle) return;
    emit(state.copyWith(type: event.type));
  }

  Future<void> _onStarted(
    RecordStarted event,
    Emitter<RecordState> emit,
  ) async {
    if (state.status != RecordStatus.idle) return;
    // Clear a previous failure so a repeated one still reaches listeners.
    if (state.failure != null) emit(state.copyWith());
    final access = await _tracker.requestAccess();
    if (access != LocationAccess.granted) {
      emit(state.copyWith(failure: RecordFailure.fromAccess(access)));
      return;
    }
    _session = RecordingSession(type: state.type, startedAt: _clock());
    _vehicle = VehicleDetector(VehicleThresholds.forType(state.type));
    _startStreams();
    emit(RecordState(type: state.type, status: RecordStatus.recording));
  }

  void _onLocationReceived(_LocationReceived event, Emitter<RecordState> emit) {
    final session = _session;
    if (session == null) return;
    final change = _vehicle?.add(event.point);
    if (change != null) {
      _onVehicleChanged(session, change, emit);
    } else if (session.addPoint(event.point)) {
      emit(_snapshot(session, state.status));
    }
  }

  /// In a vehicle the recording pauses itself, back to when the ride
  /// began; out of it, it resumes from when the athlete got out.
  void _onVehicleChanged(
    RecordingSession session,
    VehicleChange change,
    Emitter<RecordState> emit,
  ) {
    final now = _clock();
    if (change.inVehicle) {
      if (state.status != RecordStatus.recording) return;
      session.pauseFrom(change.since, now);
      emit(_withLaps(session, RecordStatus.paused, inVehicle: true));
    } else {
      if (!state.inVehicle) return;
      final fixes = _vehicle!.fixesSince(change.since);
      session.resumeFrom(change.since, fixes, now);
      emit(_withLaps(session, RecordStatus.recording, inVehicle: false));
    }
  }

  void _onTicked(_Ticked event, Emitter<RecordState> emit) {
    final session = _session;
    if (session == null) return;
    emit(state.copyWith(movingTime: session.movingTime(_clock())));
  }

  Future<void> _onPaused(RecordPaused event, Emitter<RecordState> emit) async {
    final session = _session;
    if (session == null || state.status != RecordStatus.recording) return;
    session.pause(_clock());
    await _stopStreams();
    emit(_snapshot(session, RecordStatus.paused));
  }

  void _onResumed(RecordResumed event, Emitter<RecordState> emit) {
    final session = _session;
    if (session == null || state.status != RecordStatus.paused) return;
    session.resume(_clock());
    // After a manual pause, or "not in a vehicle": judge the speed afresh.
    _vehicle?.reset();
    if (_locationSub == null) _startStreams();
    emit(_snapshot(session, RecordStatus.recording, inVehicle: false));
  }

  void _onLapped(RecordLapped event, Emitter<RecordState> emit) {
    final session = _session;
    if (session == null || state.status != RecordStatus.recording) return;
    if (!session.lap(_clock())) return;
    final mark = session.laps.last;
    emit(
      state.copyWith(
        lapNumber: session.lapNumber,
        lapStartMeters: mark.distanceMeters,
        lapStartTime: mark.movingTime,
        movingTime: mark.movingTime,
      ),
    );
  }

  Future<void> _onFinished(
    RecordFinished event,
    Emitter<RecordState> emit,
  ) async {
    final session = _session;
    if (session == null || !state.isActive) return;
    final now = _clock();
    session.pause(now);
    await _stopStreams();
    emit(_snapshot(session, RecordStatus.saving));
    try {
      final activity = await _saveActivity(
        session,
        title: defaultActivityTitle(session.type, session.startedAt),
        endedAt: now,
      );
      _session = null;
      _vehicle = null;
      emit(
        state.copyWith(
          status: RecordStatus.saved,
          savedActivityId: activity.id,
        ),
      );
    } on ActivityTooShortException {
      emit(
        state.copyWith(
          status: RecordStatus.paused,
          inVehicle: false,
          failure: RecordFailure.tooShort,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RecordStatus.paused,
          inVehicle: false,
          failure: RecordFailure.saveFailed,
        ),
      );
    }
  }

  Future<void> _onReset(RecordReset event, Emitter<RecordState> emit) async {
    await _stopStreams();
    _session = null;
    _vehicle = null;
    emit(RecordState(type: state.type));
  }

  Future<void> _onLocationFailed(
    _LocationFailed event,
    Emitter<RecordState> emit,
  ) async {
    final session = _session;
    final watching = state.status == RecordStatus.recording || state.inVehicle;
    if (session == null || !watching) return;
    session.pause(_clock());
    await _stopStreams();
    emit(
      _snapshot(
        session,
        RecordStatus.paused,
        inVehicle: false,
      ).copyWith(failure: RecordFailure.locationLost),
    );
  }

  RecordState _snapshot(
    RecordingSession session,
    RecordStatus status, {
    bool? inVehicle,
  }) {
    return state.copyWith(
      status: status,
      inVehicle: inVehicle,
      segments: session.segments,
      revision: state.revision + 1,
      distanceMeters: session.distanceMeters,
      elevationGainMeters: session.elevationGainMeters,
      movingTime: session.movingTime(_clock()),
    );
  }

  /// A snapshot that also re-reads the laps (a vehicle rewind can drop
  /// some).
  RecordState _withLaps(
    RecordingSession session,
    RecordStatus status, {
    required bool inVehicle,
  }) {
    final last = session.laps.isEmpty ? null : session.laps.last;
    return _snapshot(session, status, inVehicle: inVehicle).copyWith(
      lapNumber: session.lapNumber,
      lapStartMeters: last?.distanceMeters ?? 0,
      lapStartTime: last?.movingTime ?? Duration.zero,
    );
  }

  void _startStreams() {
    _locationSub = _tracker
        .watch(state.type)
        .listen(
          (point) => add(_LocationReceived(point)),
          onError: (Object _) => add(const _LocationFailed()),
        );
    _tickerSub = Stream<void>.periodic(
      tickInterval,
    ).listen((_) => add(const _Ticked()));
  }

  Future<void> _stopStreams() async {
    await _locationSub?.cancel();
    await _tickerSub?.cancel();
    _locationSub = null;
    _tickerSub = null;
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
