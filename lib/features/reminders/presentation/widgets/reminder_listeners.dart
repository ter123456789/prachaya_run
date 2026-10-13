import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/units/distance_unit.dart';
import '../../../activity/domain/entities/weekly_stats.dart';
import '../../../activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import '../../../athlete/presentation/bloc/units_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../../../training/presentation/bloc/training_cubit.dart';
import '../../../training/presentation/pages/schedule_page.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_scheduler.dart';
import '../bloc/reminders_cubit.dart';
import '../reminder_coordinator.dart';

/// Re-plans the device's reminders whenever the plans, the settings, the
/// unit or the latest activity change, and opens the right screen when a
/// reminder is tapped.
class ReminderListeners extends StatefulWidget {
  const ReminderListeners({
    super.key,
    required this.scheduler,
    required this.coordinator,
    required this.navigatorKey,
    required this.child,
  });

  final ReminderScheduler scheduler;
  final ReminderCoordinator coordinator;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ReminderListeners> createState() => _ReminderListenersState();
}

class _ReminderListenersState extends State<ReminderListeners> {
  StreamSubscription<ReminderTarget>? _taps;
  bool _askedPermission = false;

  /// The week as last loaded, so a goal is celebrated once, on the change.
  WeeklyStats? _lastWeek;

  @override
  void initState() {
    super.initState();
    _taps = widget.scheduler.taps.listen(_open);
    unawaited(
      widget.scheduler.launchTarget().then((t) {
        if (t != null) _open(t);
      }),
    );
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _open(ReminderTarget target) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    switch (target) {
      case ScheduleTarget(:final day):
        navigator.push(SchedulePage.route(day: day));
      case HomeTarget():
        navigator.popUntil((r) => r.isFirst);
    }
  }

  UnitFormat get _units => UnitFormat(context.read<UnitsCubit>().state);

  Future<void> _planWorkouts() async {
    final reminders = context.read<RemindersCubit>();
    final training = context.read<TrainingCubit>().state;
    if (!reminders.state.loaded || !training.loaded) return;
    final settings = reminders.state.settings;
    // Ask once per launch, as soon as there is something to remind about.
    if (!_askedPermission &&
        settings.workoutLeadMinutes != null &&
        training.upcoming.any((w) => !w.isRest)) {
      _askedPermission = true;
      await reminders.ensurePermission();
    }
    await widget.coordinator.planWorkouts(training.workouts, settings, _units);
  }

  Future<void> _planWeather() async {
    final reminders = context.read<RemindersCubit>().state;
    if (!reminders.loaded) return;
    final latest = context.read<DashboardCubit>().state.latest;
    final start = latest == null || latest.segments.isEmpty
        ? null
        : latest.segments.first.first;
    await widget.coordinator.planWeather(
      start == null ? null : (lat: start.latitude, lng: start.longitude),
      reminders.settings,
      _units,
    );
  }

  void _replanAll() {
    unawaited(_planWorkouts());
    unawaited(_planWeather());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TrainingCubit, TrainingState>(
          listenWhen: (prev, curr) =>
              curr.loaded && prev.workouts != curr.workouts,
          listener: (_, _) => unawaited(_planWorkouts()),
        ),
        BlocListener<RemindersCubit, RemindersState>(
          listenWhen: (prev, curr) =>
              curr.loaded && prev.settings != curr.settings,
          listener: (_, _) => _replanAll(),
        ),
        BlocListener<UnitsCubit, DistanceUnit>(
          listener: (_, _) => _replanAll(),
        ),
        BlocListener<DashboardCubit, DashboardState>(
          listenWhen: (prev, curr) =>
              curr.status == DashboardStatus.loaded &&
              (prev.week?.distanceMeters != curr.week?.distanceMeters ||
                  prev.latest?.id != curr.latest?.id),
          listener: (context, state) {
            final reminders = context.read<RemindersCubit>().state;
            final before = _lastWeek;
            _lastWeek = state.week;
            if (before != null && state.week != null && reminders.loaded) {
              unawaited(
                widget.coordinator.weekChanged(
                  before,
                  state.week!,
                  reminders.settings,
                  _units,
                ),
              );
            }
            unawaited(_planWeather());
          },
        ),
      ],
      child: widget.child,
    );
  }
}
