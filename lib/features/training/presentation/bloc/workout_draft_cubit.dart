import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/services/uuid.dart';
import '../../domain/entities/planned_workout.dart';
import '../../domain/services/workout_plan.dart';

/// The "new workout" sheet's form: a [PlannedWorkout] being edited.
final class WorkoutDraftState extends Equatable {
  const WorkoutDraftState(
    this.workout, {
    this.isNew = true,
    this.error = false,
  });

  final PlannedWorkout workout;
  final bool isNew;

  /// The last save was rejected (e.g. empty title).
  final bool error;

  List<WorkoutPhase> get phases => workoutPhases(workout);
  Duration? get estimate => estimatedDuration(workout);
  bool get valid => isValidWorkout(workout);

  @override
  List<Object?> get props => [workout, isNew, error];
}

class WorkoutDraftCubit extends Cubit<WorkoutDraftState> {
  /// A new session on [day] at 18:30 (or [existing] to edit it).
  WorkoutDraftCubit({
    required DateTime day,
    PlannedWorkout? existing,
    String Function() newId = uuidV4,
  }) : super(
         existing != null
             ? WorkoutDraftState(existing, isNew: false)
             : WorkoutDraftState(
                 _fromTemplate(newId(), WorkoutType.tempo, day),
               ),
       );

  static const _stepMeters = 500.0;
  static const _paceStep = 5;

  static PlannedWorkout _fromTemplate(
    String id,
    WorkoutType type,
    DateTime day,
  ) {
    final t = templateFor(type);
    return PlannedWorkout(
      id: id,
      type: type,
      title: t.title,
      scheduledAt: DateTime(day.year, day.month, day.day, 18, 30),
      distanceMeters: t.distanceMeters,
      paceMinSecPerKm: t.paceMinSecPerKm,
      paceMaxSecPerKm: t.paceMaxSecPerKm,
    );
  }

  PlannedWorkout get _w => state.workout;

  void _set(PlannedWorkout w) => emit(WorkoutDraftState(w, isNew: state.isNew));

  /// Switching type loads that type's starting distance, pace and title
  /// (the title only if it was still the previous type's default).
  void setType(WorkoutType type) {
    if (type == _w.type) return;
    final t = templateFor(type);
    final keepTitle = _w.title != templateFor(_w.type).title;
    _set(
      _w.copyWith(
        type: type,
        title: keepTitle ? _w.title : t.title,
        distanceMeters: t.distanceMeters,
        paceMinSecPerKm: () => t.paceMinSecPerKm,
        paceMaxSecPerKm: () => t.paceMaxSecPerKm,
      ),
    );
  }

  void setTitle(String title) => _set(_w.copyWith(title: title));

  void setLocation(String? location) =>
      _set(_w.copyWith(location: () => location));

  void setDay(DateTime day) => _set(
    _w.copyWith(
      scheduledAt: DateTime(
        day.year,
        day.month,
        day.day,
        _w.scheduledAt.hour,
        _w.scheduledAt.minute,
      ),
    ),
  );

  void setTime(int hour, int minute) {
    final d = _w.scheduledAt;
    _set(
      _w.copyWith(scheduledAt: DateTime(d.year, d.month, d.day, hour, minute)),
    );
  }

  /// ±0.5 km, between 0.5 and 100 km.
  void stepDistance(int direction) {
    if (_w.isRest) return;
    final next = (_w.distanceMeters + direction * _stepMeters).clamp(
      _stepMeters,
      100000.0,
    );
    _set(_w.copyWith(distanceMeters: next));
  }

  /// Shifts the whole pace range by ±5 s/km (negative = faster).
  void stepPace(int direction) {
    final min = _w.paceMinSecPerKm;
    final max = _w.paceMaxSecPerKm;
    if (min == null || max == null) return;
    final delta = direction * _paceStep;
    if (min + delta < 120 || max + delta > 1200) return;
    _set(
      _w.copyWith(
        paceMinSecPerKm: () => min + delta,
        paceMaxSecPerKm: () => max + delta,
      ),
    );
  }

  /// The workout to save, or null (with [WorkoutDraftState.error]) when it
  /// is not valid yet.
  PlannedWorkout? submit() {
    if (!state.valid) {
      emit(WorkoutDraftState(_w, isNew: state.isNew, error: true));
      return null;
    }
    return _w;
  }
}
