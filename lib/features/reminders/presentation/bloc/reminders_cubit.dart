import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/reminder_settings.dart';
import '../../domain/repositories/reminder_scheduler.dart';
import '../../domain/repositories/reminder_settings_repository.dart';

final class RemindersState extends Equatable {
  const RemindersState({
    this.settings = const ReminderSettings(),
    this.loaded = false,
    this.permissionDenied = false,
  });

  final ReminderSettings settings;
  final bool loaded;

  /// Notifications are off in the OS settings: the toggles say so.
  final bool permissionDenied;

  @override
  List<Object?> get props => [settings, loaded, permissionDenied];
}

/// Notification and voice settings (Stitch 08 settings, 10 reminder row).
class RemindersCubit extends Cubit<RemindersState> {
  RemindersCubit(this._settings, this._scheduler)
    : super(const RemindersState());

  final ReminderSettingsRepository _settings;
  final ReminderScheduler _scheduler;

  Future<void> load() async {
    final settings = await _settings.load();
    if (isClosed) return;
    emit(RemindersState(settings: settings, loaded: true));
  }

  /// Minutes before each planned session; null = off.
  Future<void> setWorkoutLead(int? minutes) => _update(
    state.settings.copyWith(workoutLeadMinutes: () => minutes),
    notifies: minutes != null,
  );

  Future<void> setWeeklyGoal(bool on) =>
      _update(state.settings.copyWith(weeklyGoal: on), notifies: on);

  Future<void> setMorningWeather(bool on) =>
      _update(state.settings.copyWith(morningWeather: on), notifies: on);

  Future<void> setAudioCues(bool on) =>
      _update(state.settings.copyWith(audioCues: on), notifies: false);

  /// The first time a notification is turned on, the OS asks.
  Future<void> ensurePermission() async {
    final s = state.settings;
    if (s.workoutLeadMinutes == null && !s.weeklyGoal && !s.morningWeather) {
      return;
    }
    final allowed = await _scheduler.requestPermission();
    if (isClosed) return;
    emit(
      RemindersState(
        settings: state.settings,
        loaded: state.loaded,
        permissionDenied: !allowed,
      ),
    );
  }

  Future<void> _update(ReminderSettings next, {required bool notifies}) async {
    emit(
      RemindersState(
        settings: next,
        loaded: true,
        permissionDenied: state.permissionDenied,
      ),
    );
    await _settings.save(next);
    if (notifies) await ensurePermission();
  }
}
