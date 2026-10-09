import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/dashboard/dashboard_cubit.dart';
import 'bloc/history/history_cubit.dart';

extension ActivityRefresh on BuildContext {
  /// Reloads every screen that lists activities after a save or delete.
  Future<void> refreshActivities() =>
      Future.wait([read<HistoryCubit>().load(), read<DashboardCubit>().load()]);
}
