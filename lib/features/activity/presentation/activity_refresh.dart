import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/dashboard/dashboard_cubit.dart';
import 'bloc/history/history_cubit.dart';
import 'bloc/sync/sync_cubit.dart';

extension ActivityRefresh on BuildContext {
  /// Reloads every screen that lists activities after a save or delete.
  Future<void> refreshActivities() =>
      Future.wait([read<HistoryCubit>().load(), read<DashboardCubit>().load()]);

  /// Pull-to-refresh: syncs with the server (if signed in), then reloads.
  Future<void> syncActivities() async {
    final history = read<HistoryCubit>();
    final dashboard = read<DashboardCubit>();
    await read<SyncCubit>().sync();
    await Future.wait([history.load(), dashboard.load()]);
  }
}
