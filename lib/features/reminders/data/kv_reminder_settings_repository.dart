import '../../../core/storage/kv_store.dart';
import '../domain/entities/reminder_settings.dart';
import '../domain/repositories/reminder_settings_repository.dart';

/// In the device's `settings` row, next to the distance unit (kept when
/// local data is cleared, never synced).
class KvReminderSettingsRepository implements ReminderSettingsRepository {
  KvReminderSettingsRepository(this._kv);

  static const _key = 'settings';
  static const _field = 'reminders';

  final KvStore _kv;

  @override
  Future<ReminderSettings> load() async {
    final json = (await _kv.read(_key))?[_field] as Map<String, Object?>?;
    if (json == null) return const ReminderSettings();
    const d = ReminderSettings();
    return ReminderSettings(
      workoutLeadMinutes: json.containsKey('workoutLeadMinutes')
          ? json['workoutLeadMinutes'] as int?
          : d.workoutLeadMinutes,
      weeklyGoal: json['weeklyGoal'] as bool? ?? d.weeklyGoal,
      morningWeather: json['morningWeather'] as bool? ?? d.morningWeather,
      audioCues: json['audioCues'] as bool? ?? d.audioCues,
    );
  }

  @override
  Future<void> save(ReminderSettings s) async {
    final json = await _kv.read(_key) ?? {};
    await _kv.write(_key, {
      ...json,
      _field: {
        'workoutLeadMinutes': s.workoutLeadMinutes,
        'weeklyGoal': s.weeklyGoal,
        'morningWeather': s.morningWeather,
        'audioCues': s.audioCues,
      },
    });
  }
}
