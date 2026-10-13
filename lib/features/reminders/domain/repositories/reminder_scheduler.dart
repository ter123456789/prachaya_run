import '../entities/reminder.dart';

/// The device's notification system.
abstract interface class ReminderScheduler {
  /// Asks the OS once; returns whether notifications are allowed.
  Future<bool> requestPermission();

  /// Replaces every pending reminder of [kind] with [reminders].
  Future<void> replace(ReminderKind kind, List<Reminder> reminders);

  /// Shows [reminder] straight away.
  Future<void> showNow(Reminder reminder);

  /// Reminders the user taps while the app runs.
  Stream<ReminderTarget> get taps;

  /// The reminder that launched the app, if any (read once).
  Future<ReminderTarget?> launchTarget();
}
