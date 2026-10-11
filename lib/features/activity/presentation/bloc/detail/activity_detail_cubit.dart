import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_insights.dart';
import '../../../domain/entities/activity_photo.dart';
import '../../../domain/entities/weather_report.dart';
import '../../../domain/repositories/activity_photo_repository.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/services/weather_service.dart';

enum ActivityDetailStatus { loading, loaded, notFound, failure, deleted }

final class ActivityDetailState extends Equatable {
  const ActivityDetailState({
    this.status = ActivityDetailStatus.loading,
    this.activity,
    this.insights,
    this.weather,
    this.photos = const [],
    this.addingPhoto = false,
  });

  final ActivityDetailStatus status;
  final Activity? activity;
  final ActivityInsights? insights;

  /// At the start of the activity; null until loaded or unavailable.
  final WeatherReport? weather;
  final List<ActivityPhoto> photos;
  final bool addingPhoto;

  ActivityDetailState copyWith({
    ActivityDetailStatus? status,
    WeatherReport? weather,
    List<ActivityPhoto>? photos,
    bool? addingPhoto,
  }) => ActivityDetailState(
    status: status ?? this.status,
    activity: activity,
    insights: insights,
    weather: weather ?? this.weather,
    photos: photos ?? this.photos,
    addingPhoto: addingPhoto ?? this.addingPhoto,
  );

  @override
  List<Object?> get props => [
    status,
    activity,
    insights?.effort,
    insights?.distanceVsAveragePercent,
    weather?.temperatureC,
    weather?.kind,
    photos,
    addingPhoto,
  ];
}

class ActivityDetailCubit extends Cubit<ActivityDetailState> {
  ActivityDetailCubit(
    this._repository,
    this.activityId, {
    ActivityPhotoRepository? photos,
    WeatherService? weather,
  }) : _photos = photos,
       _weather = weather,
       super(const ActivityDetailState());

  final ActivityRepository _repository;
  final ActivityPhotoRepository? _photos;
  final WeatherService? _weather;
  final String activityId;

  Future<void> load() async {
    try {
      final activity = await _repository.getById(activityId);
      if (activity == null) {
        emit(const ActivityDetailState(status: ActivityDetailStatus.notFound));
        return;
      }
      final history = await _repository.getAll();
      final photos = await _photos?.photosOf(activityId) ?? const [];
      emit(
        ActivityDetailState(
          status: ActivityDetailStatus.loaded,
          activity: activity,
          insights: ActivityInsights.of(activity, history: history),
          photos: photos,
        ),
      );
      await _loadWeather(activity);
    } catch (_) {
      emit(const ActivityDetailState(status: ActivityDetailStatus.failure));
    }
  }

  Future<void> _loadWeather(Activity activity) async {
    final service = _weather;
    if (service == null || activity.segments.isEmpty) return;
    final p = activity.segments.first.first;
    final report = await service.at(
      lat: p.latitude,
      lng: p.longitude,
      time: activity.startedAt,
    );
    if (report != null && !isClosed) emit(state.copyWith(weather: report));
  }

  Future<void> addPhoto(List<int> bytes) async {
    final photos = _photos;
    if (photos == null) return;
    emit(state.copyWith(addingPhoto: true));
    await photos.add(activityId, bytes, takenAt: DateTime.now());
    emit(
      state.copyWith(
        addingPhoto: false,
        photos: await photos.photosOf(activityId),
      ),
    );
  }

  Future<void> deletePhoto(ActivityPhoto photo) async {
    final photos = _photos;
    if (photos == null) return;
    await photos.delete(photo);
    emit(state.copyWith(photos: await photos.photosOf(activityId)));
  }

  Future<void> delete() async {
    await _repository.delete(activityId);
    emit(const ActivityDetailState(status: ActivityDetailStatus.deleted));
  }
}
