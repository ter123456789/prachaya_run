import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/splash/splash_page.dart';
import 'core/theme/app_theme.dart';
import 'features/activity/domain/repositories/activity_repository.dart';
import 'features/activity/domain/services/activity_sync.dart';
import 'features/activity/domain/services/location_tracker.dart';
import 'features/activity/domain/usecases/save_activity.dart';
import 'features/activity/presentation/activity_refresh.dart';
import 'features/activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import 'features/activity/presentation/bloc/history/history_cubit.dart';
import 'features/activity/presentation/bloc/record/record_bloc.dart';
import 'features/activity/presentation/bloc/sync/sync_cubit.dart';
import 'features/activity/presentation/pages/home_page.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/debug/domain/services/debug_tools.dart';
import 'features/debug/presentation/debug_cubit.dart';
import 'features/debug/presentation/debug_overlay.dart';
import 'features/photo_share/domain/services/image_sink.dart';
import 'features/photo_share/domain/services/photo_source.dart';

class PrachayaRunApp extends StatelessWidget {
  const PrachayaRunApp({
    super.key,
    required this.activityRepository,
    required this.activitySync,
    required this.authRepository,
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
        RepositoryProvider.value(value: photoSource),
        RepositoryProvider.value(value: imageSink),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => RecordBloc(
              locationTracker: locationTracker,
              saveActivity: SaveActivity(activityRepository),
              clock: clock,
            ),
          ),
          BlocProvider(create: (_) => HistoryCubit(activityRepository)..load()),
          BlocProvider(
            create: (_) => DashboardCubit(activityRepository)..load(),
          ),
          BlocProvider(create: (_) => SyncCubit(activitySync)),
          BlocProvider(create: (_) => AuthCubit(authRepository)..start()),
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
                if (state.status == AuthStatus.signedIn) {
                  context.read<SyncCubit>().sync();
                }
              },
            ),
            // Activities pulled from other devices show up straight away.
            BlocListener<SyncCubit, SyncState>(
              listenWhen: (prev, curr) => prev.revision != curr.revision,
              listener: (context, _) => context.refreshActivities(),
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
