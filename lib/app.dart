import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/splash/splash_page.dart';
import 'core/theme/app_theme.dart';
import 'features/activity/domain/repositories/activity_repository.dart';
import 'features/activity/domain/services/location_tracker.dart';
import 'features/activity/domain/usecases/save_activity.dart';
import 'features/activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import 'features/activity/presentation/bloc/history/history_cubit.dart';
import 'features/activity/presentation/bloc/record/record_bloc.dart';
import 'features/activity/presentation/pages/home_page.dart';
import 'features/photo_share/domain/services/image_sink.dart';
import 'features/photo_share/domain/services/photo_source.dart';

class PrachayaRunApp extends StatelessWidget {
  const PrachayaRunApp({
    super.key,
    required this.activityRepository,
    required this.locationTracker,
    required this.photoSource,
    required this.imageSink,
  });

  final ActivityRepository activityRepository;
  final LocationTracker locationTracker;
  final PhotoSource photoSource;
  final ImageSink imageSink;

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
            ),
          ),
          BlocProvider(create: (_) => HistoryCubit(activityRepository)..load()),
          BlocProvider(
            create: (_) => DashboardCubit(activityRepository)..load(),
          ),
        ],
        child: MaterialApp(
          title: 'Prachaya Run',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: SplashPage(next: (_) => const HomePage()),
        ),
      ),
    );
  }
}
