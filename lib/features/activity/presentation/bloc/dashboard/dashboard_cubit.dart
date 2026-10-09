import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/weekly_stats.dart';
import '../../../domain/repositories/activity_repository.dart';

enum DashboardStatus { loading, loaded, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.week,
    this.latest,
  });

  final DashboardStatus status;
  final WeeklyStats? week;

  /// Most recent activity with its full track, for the route preview.
  final Activity? latest;

  @override
  List<Object?> get props => [status, week, latest];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const DashboardState());

  final ActivityRepository _repository;
  final DateTime Function() _clock;

  Future<void> load() async {
    try {
      final summaries = await _repository.getAll();
      final latest = summaries.isEmpty
          ? null
          : await _repository.getById(summaries.first.id);
      emit(
        DashboardState(
          status: DashboardStatus.loaded,
          week: WeeklyStats.from(summaries, _clock()),
          latest: latest,
        ),
      );
    } catch (_) {
      emit(
        DashboardState(
          status: DashboardStatus.failure,
          week: state.week,
          latest: state.latest,
        ),
      );
    }
  }
}
