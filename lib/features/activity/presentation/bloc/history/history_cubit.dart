import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_type.dart';
import '../../../domain/repositories/activity_repository.dart';

enum HistoryStatus { loading, loaded, failure }

final class HistoryState extends Equatable {
  const HistoryState({
    this.status = HistoryStatus.loading,
    this.activities = const [],
    this.filter,
  });

  final HistoryStatus status;
  final List<ActivitySummary> activities;

  /// null shows every type.
  final ActivityType? filter;

  List<ActivitySummary> get visible => filter == null
      ? activities
      : activities.where((a) => a.type == filter).toList();

  @override
  List<Object?> get props => [status, activities, filter];
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repository) : super(const HistoryState());

  final ActivityRepository _repository;

  Future<void> load() async {
    emit(HistoryState(activities: state.activities, filter: state.filter));
    try {
      final activities = await _repository.getAll();
      emit(
        HistoryState(
          status: HistoryStatus.loaded,
          activities: activities,
          filter: state.filter,
        ),
      );
    } catch (_) {
      emit(
        HistoryState(
          status: HistoryStatus.failure,
          activities: state.activities,
          filter: state.filter,
        ),
      );
    }
  }

  void setFilter(ActivityType? filter) => emit(
    HistoryState(
      status: state.status,
      activities: state.activities,
      filter: filter,
    ),
  );
}
