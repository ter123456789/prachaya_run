import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/splash/splash_page.dart';
import 'core/theme/app_theme.dart';
import 'features/activity/domain/repositories/activity_photo_repository.dart';
import 'features/activity/domain/repositories/activity_repository.dart';
import 'features/activity/domain/repositories/challenge_repository.dart';
import 'features/activity/domain/entities/activity_type.dart';
import 'features/activity/domain/services/activity_sync.dart';
import 'features/activity/domain/services/location_tracker.dart';
import 'features/activity/domain/services/weather_service.dart';
import 'features/activity/domain/usecases/save_activity.dart';
import 'features/activity/presentation/activity_refresh.dart';
import 'features/activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import 'features/activity/presentation/bloc/history/history_cubit.dart';
import 'features/activity/presentation/bloc/record/record_bloc.dart';
import 'features/activity/presentation/bloc/sync/sync_cubit.dart';
import 'features/activity/presentation/pages/home_page.dart';
import 'features/athlete/domain/repositories/settings_repository.dart';
import 'features/athlete/domain/repositories/shoe_repository.dart';
import 'features/athlete/presentation/bloc/gear_cubit.dart';
import 'features/athlete/presentation/bloc/units_cubit.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/profile_repository.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/auth/presentation/bloc/profile_cubit.dart';
import 'features/debug/domain/services/debug_tools.dart';
import 'features/debug/presentation/debug_cubit.dart';
import 'features/debug/presentation/debug_overlay.dart';
import 'features/photo_share/domain/services/image_sink.dart';
import 'features/photo_share/domain/services/photo_source.dart';
import 'features/training/domain/repositories/workout_repository.dart';
import 'features/training/domain/usecases/complete_workout.dart';
import 'features/training/presentation/bloc/training_cubit.dart';

class PrachayaRunApp extends StatelessWidget {
  const PrachayaRunApp({
    super.key,
    required this.activityRepository,
    required this.activitySync,
    required this.authRepository,
    required this.profileRepository,
    required this.photoRepository,
    required this.shoeRepository,
    required this.workoutRepository,
    required this.settingsRepository,
    this.challengeRepository,
    this.weatherService,
    required this.locationTracker,
    required this.photoSource,
    required this.imageSink,
    this.debugTools,
    this.clock,
  });

  static final _navigatorKey = GlobalKey<NavigatorState>();

  final ActivityRepository activityRepository;
  final ActivitySync activitySync;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ActivityPhotoRepository photoRepository;
  final ShoeRepository shoeRepository;
  final WorkoutRepository workoutRepository;
  final SettingsRepository settingsRepository;
  final ChallengeRepository? challengeRepository;
  final WeatherService? weatherService;
  final LocationTracker locationTracker;
  final PhotoSource photoSource;
  final ImageSink imageSink;

  /// Debug builds only: enables the floating test-tools button.
  final DebugTools? debugTools;

  /// Time source for recording (debug builds pass a speed-up clock).
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: activityRepository),
        RepositoryProvider.value(value: photoRepository),
        RepositoryProvider<WeatherService?>.value(value: weatherService),
        RepositoryProvider.value(value: photoSource),
        RepositoryProvider.value(value: imageSink),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => RecordBloc(
              locationTracker: locationTracker,
              saveActivity: SaveActivity(
                activityRepository,
                // Runs and hikes count toward the primary shoe.
                defaultShoe: (type) async => type == ActivityType.ride
                    ? null
                    : (await shoeRepository.primary())?.id,
                onSaved: [
                  (a) => CompleteWorkoutForActivity(workoutRepository)(a),
                ],
              ),
              clock: clock,
            ),
          ),
          BlocProvider(create: (_) => HistoryCubit(activityRepository)..load()),
          BlocProvider(
            create: (_) => DashboardCubit(
              activityRepository,
              challenges: challengeRepository,
              weather: weatherService,
            )..load(),
          ),
          BlocProvider(create: (_) => SyncCubit(activitySync)),
          BlocProvider(create: (_) => AuthCubit(authRepository)..start()),
          BlocProvider(create: (_) => ProfileCubit(profileRepository)..load()),
          BlocProvider(create: (_) => UnitsCubit(settingsRepository)..load()),
          BlocProvider(
            create: (_) =>
                GearCubit(shoeRepository, activityRepository)..load(),
          ),
          BlocProvider(
            create: (_) =>
                TrainingCubit(workoutRepository, activityRepository)..load(),
          ),
          if (debugTools case final tools?)
            BlocProvider(create: (_) => DebugCubit(tools)),
        ],
        child: MultiBlocListener(
          listeners: [
            // Each account sees its own activities: reload on sign-in/out,
            // and sync on launch with a saved session and after sign-in.
            BlocListener<AuthCubit, AuthState>(
              listenWhen: (prev, curr) =>
                  prev.user != curr.user && curr.status != AuthStatus.unknown,
              listener: (context, state) {
                context.refreshActivities();
                // Signed out shows the device's own profile.
                context.read<ProfileCubit>().load();
                if (state.status == AuthStatus.signedIn) {
                  context.read<SyncCubit>().sync();
                }
              },
            ),
            // Activities pulled from other devices show up straight away.
            BlocListener<SyncCubit, SyncState>(
              listenWhen: (prev, curr) => prev.revision != curr.revision,
              listener: (context, _) {
                context.refreshActivities();
                context.read<ProfileCubit>().load();
              },
            ),
          ],
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            builder: debugTools == null
                ? null
                : (context, child) =>
                      DebugOverlay(navigatorKey: _navigatorKey, child: child!),
            title: 'Prachaya Run',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: SplashPage(next: (_) => const HomePage()),
          ),
        ),
      ),
    );
  }
}
