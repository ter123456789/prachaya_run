import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../athlete/presentation/bloc/gear_cubit.dart';
import '../../route_builder/presentation/bloc/routes_cubit.dart';
import '../../training/presentation/bloc/training_cubit.dart';
import 'bloc/dashboard/dashboard_cubit.dart';
import 'bloc/history/history_cubit.dart';
import 'bloc/sync/sync_cubit.dart';

extension ActivityRefresh on BuildContext {
  /// Reloads every screen that lists activities (or derives from them, like
  /// shoe mileage and finished workouts) after a save or delete. Also runs
  /// on sign-in/out and after a sync, so it reloads the saved routes too.
  Future<void> refreshActivities() => _reload(this);

  /// Pull-to-refresh: syncs with the server (if signed in), then reloads.
  Future<void> syncActivities() async {
    final reload = _reloaders(this);
    await read<SyncCubit>().sync();
    await Future.wait(reload.map((r) => r()));
  }
}

Future<void> _reload(BuildContext context) =>
    Future.wait(_reloaders(context).map((r) => r()));

/// Read up front so nothing touches [context] after an await.
List<Future<void> Function()> _reloaders(BuildContext context) => [
  context.read<HistoryCubit>().load,
  context.read<DashboardCubit>().load,
  context.read<GearCubit>().load,
  context.read<TrainingCubit>().load,
  context.read<RoutesCubit>().load,
];
