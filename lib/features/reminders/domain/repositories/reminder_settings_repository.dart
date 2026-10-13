import '../entities/reminder_settings.dart';

abstract interface class ReminderSettingsRepository {
  /// Defaults until changed.
  Future<ReminderSettings> load();

  Future<void> save(ReminderSettings settings);
}
