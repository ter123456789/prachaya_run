import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';

enum ActivityDetailStatus { loading, loaded, notFound, failure, deleted }

final class ActivityDetailState extends Equatable {
  const ActivityDetailState({
    this.status = ActivityDetailStatus.loading,
    this.activity,
  });

  final ActivityDetailStatus status;
  final Activity? activity;

  @override
  List<Object?> get props => [status, activity];
}

class ActivityDetailCubit extends Cubit<ActivityDetailState> {
  ActivityDetailCubit(this._repository, this.activityId)
    : super(const ActivityDetailState());

  final ActivityRepository _repository;
  final String activityId;

  Future<void> load() async {
    try {
      final activity = await _repository.getById(activityId);
      emit(
        activity == null
            ? const ActivityDetailState(status: ActivityDetailStatus.notFound)
            : ActivityDetailState(
                status: ActivityDetailStatus.loaded,
                activity: activity,
              ),
      );
    } catch (_) {
      emit(const ActivityDetailState(status: ActivityDetailStatus.failure));
    }
  }

  Future<void> delete() async {
    await _repository.delete(activityId);
    emit(const ActivityDetailState(status: ActivityDetailStatus.deleted));
  }
}
