import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity_type.dart';
import '../../../domain/entities/recording_session.dart';
import '../../../domain/entities/track_point.dart';
import '../../../domain/services/location_tracker.dart';
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
    _startStreams();
    emit(RecordState(type: state.type, status: RecordStatus.recording));
  }

  void _onLocationReceived(_LocationReceived event, Emitter<RecordState> emit) {
    final session = _session;
    if (session == null || !session.addPoint(event.point)) return;
    emit(_snapshot(session, state.status));
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
    _startStreams();
    emit(_snapshot(session, RecordStatus.recording));
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
          failure: RecordFailure.tooShort,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RecordStatus.paused,
          failure: RecordFailure.saveFailed,
        ),
      );
    }
  }

  Future<void> _onReset(RecordReset event, Emitter<RecordState> emit) async {
    await _stopStreams();
    _session = null;
    emit(RecordState(type: state.type));
  }

  Future<void> _onLocationFailed(
    _LocationFailed event,
    Emitter<RecordState> emit,
  ) async {
    final session = _session;
    if (session == null || state.status != RecordStatus.recording) return;
    session.pause(_clock());
    await _stopStreams();
    emit(
      _snapshot(
        session,
        RecordStatus.paused,
      ).copyWith(failure: RecordFailure.locationLost),
    );
  }

  RecordState _snapshot(RecordingSession session, RecordStatus status) {
    return state.copyWith(
      status: status,
      segments: session.segments,
      revision: state.revision + 1,
      distanceMeters: session.distanceMeters,
      elevationGainMeters: session.elevationGainMeters,
      movingTime: session.movingTime(_clock()),
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
