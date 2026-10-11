import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/activity.dart';
import '../../../domain/entities/activity_insights.dart';
import '../../../domain/entities/monthly_challenge.dart';
import '../../../domain/entities/weather_report.dart';
import '../../../domain/entities/weekly_stats.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../domain/services/weather_service.dart';

enum DashboardStatus { loading, loaded, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.week,
    this.latest,
    this.latestInsights,
    this.challenge,
    this.challengeMeters = 0,
    this.weather,
  });

  final DashboardStatus status;
  final WeeklyStats? week;

  /// Most recent activity with its full track, for the route preview.
  final Activity? latest;
  final ActivityInsights? latestInsights;
  final MonthlyChallenge? challenge;

  /// Distance this month inside the challenge window (from local data, so
  /// it matches the lists).
  final double challengeMeters;

  /// Near the latest activity's start; null until loaded or unavailable.
  final WeatherReport? weather;

  DashboardState copyWith({
    MonthlyChallenge? challenge,
    double? challengeMeters,
    WeatherReport? weather,
  }) => DashboardState(
    status: status,
    week: week,
    latest: latest,
    latestInsights: latestInsights,
    challenge: challenge ?? this.challenge,
    challengeMeters: challengeMeters ?? this.challengeMeters,
    weather: weather ?? this.weather,
  );

  @override
  List<Object?> get props => [
    status,
    week,
    latest,
    latestInsights?.effort,
    latestInsights?.totalTime,
    challenge?.id,
    challengeMeters,
    weather?.temperatureC,
    weather?.kind,
  ];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(
    this._repository, {
    ChallengeRepository? challenges,
    WeatherService? weather,
    DateTime Function()? clock,
  }) : _challenges = challenges,
       _weather = weather,
       _clock = clock ?? DateTime.now,
       super(const DashboardState());

  final ActivityRepository _repository;
  final ChallengeRepository? _challenges;
  final WeatherService? _weather;
  final DateTime Function() _clock;

  Future<void> load() async {
    final List<ActivitySummary> summaries;
    try {
      summaries = await _repository.getAll();
      final latest = summaries.isEmpty
          ? null
          : await _repository.getById(summaries.first.id);
      emit(
        DashboardState(
          status: DashboardStatus.loaded,
          week: WeeklyStats.from(summaries, _clock()),
          latest: latest,
          latestInsights: latest == null
              ? null
              : ActivityInsights.of(latest, history: summaries),
          challenge: state.challenge,
          challengeMeters: state.challengeMeters,
          weather: state.weather,
        ),
      );
    } catch (_) {
      emit(
        DashboardState(
          status: DashboardStatus.failure,
          week: state.week,
          latest: state.latest,
          challenge: state.challenge,
          weather: state.weather,
        ),
      );
      return;
    }
    // Extras arrive after the main content so the screen never waits on
    // the network.
    await Future.wait([_loadChallenge(summaries), _loadWeather()]);
  }

  Future<void> _loadChallenge(List<ActivitySummary> summaries) async {
    final challenge = await _challenges?.current();
    if (challenge == null || isClosed) return;
    final meters = summaries
        .where((a) => challenge.contains(a.startedAt))
        .fold<double>(0, (s, a) => s + a.distanceMeters);
    emit(state.copyWith(challenge: challenge, challengeMeters: meters));
  }

  Future<void> _loadWeather() async {
    final latest = state.latest;
    final service = _weather;
    if (latest == null || service == null || latest.segments.isEmpty) return;
    final p = latest.segments.first.first;
    final report = await service.current(lat: p.latitude, lng: p.longitude);
    if (report == null || isClosed) return;
    emit(state.copyWith(weather: report));
  }
}
