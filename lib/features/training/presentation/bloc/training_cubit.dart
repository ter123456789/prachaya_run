import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/repositories/activity_repository.dart';
import '../../domain/entities/planned_workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_plan.dart';

final class TrainingState extends Equatable {
  TrainingState({
    this.workouts = const [],
    this.activities = const [],
    DateTime? today,
    DateTime? selectedDay,
    this.loaded = false,
  }) : today = today ?? DateTime.now(),
       selectedDay = selectedDay ?? today ?? DateTime.now();

  final List<PlannedWorkout> workouts;
  final List<ActivitySummary> activities;
  final DateTime today;

  /// The day shown in the focus card (today unless the user taps another).
  final DateTime selectedDay;
  final bool loaded;

  late final TrainingWeek week = TrainingWeek.from(workouts, activities, today);

  /// The session in the focus card for [selectedDay].
  late final PlannedWorkout? focus = todaysWorkout(workouts, selectedDay);
  late final List<PlannedWorkout> upcoming = upcomingWorkouts(workouts, today);

  /// Earlier places, most used first, for the location chips.
  late final List<String> recentLocations = () {
    final counts = <String, int>{};
    for (final w in workouts) {
      final l = w.location;
      if (l != null) counts[l] = (counts[l] ?? 0) + 1;
    }
    return (counts.entries.toList()..sort((a, b) => b.value - a.value))
        .map((e) => e.key)
        .take(4)
        .toList();
  }();

  bool isDone(PlannedWorkout w) =>
      w.completedActivityId != null &&
      activities.any((a) => a.id == w.completedActivityId);

  TrainingState copyWith({
    List<PlannedWorkout>? workouts,
    List<ActivitySummary>? activities,
    DateTime? today,
    DateTime? selectedDay,
    bool? loaded,
  }) => TrainingState(
    workouts: workouts ?? this.workouts,
    activities: activities ?? this.activities,
    today: today ?? this.today,
    selectedDay: selectedDay ?? this.selectedDay,
    loaded: loaded ?? this.loaded,
  );

  @override
  List<Object?> get props => [workouts, activities, today, selectedDay, loaded];
}

/// Planned sessions with their completion from recorded runs.
class TrainingCubit extends Cubit<TrainingState> {
  TrainingCubit(
    this._workouts,
    this._activities, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock,
       super(TrainingState(today: clock()));

  final WorkoutRepository _workouts;
  final ActivityRepository _activities;
  final DateTime Function() _clock;

  Future<void> load() async {
    final workouts = await _workouts.getAll();
    final activities = await _activities.getAll();
    if (isClosed) return;
    final today = _clock();
    // Keep the user's day choice while it is in the shown week.
    final keep = TrainingWeek.from(
      const [],
      const [],
      today,
    ).days.any((d) => isSameDay(d.date, state.selectedDay));
    emit(
      TrainingState(
        workouts: workouts,
        activities: activities,
        today: today,
        selectedDay: keep ? state.selectedDay : today,
        loaded: true,
      ),
    );
  }

  void selectDay(DateTime day) => emit(state.copyWith(selectedDay: day));

  /// Throws [WorkoutValidationException] for invalid values.
  Future<void> save(PlannedWorkout workout) async {
    await _workouts.save(workout);
    await load();
  }

  Future<void> delete(String id) async {
    await _workouts.delete(id);
    await load();
  }
}
