/// Groups of reminders; scheduling one kind replaces only that kind.
enum ReminderKind { workout, weeklyGoal, weather }

/// A local notification to show at [at] (or now).
class Reminder {
  const Reminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.target,
  });

  /// Stable per subject, so rescheduling replaces instead of duplicating.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// What a tap opens.
  final ReminderTarget? target;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.target == target;

  @override
  int get hashCode => Object.hash(id, kind, at, title, body, target);

  @override
  String toString() => 'Reminder($id, $kind, $at, $title)';
}

/// Where tapping a reminder leads.
sealed class ReminderTarget {
  const ReminderTarget();

  /// `schedule:2026-10-14` / `home`.
  String encode();

  static ReminderTarget? decode(String? payload) {
    if (payload == null) return null;
    if (payload == 'home') return const HomeTarget();
    if (payload.startsWith('schedule:')) {
      final day = DateTime.tryParse(payload.substring(9));
      return day == null ? null : ScheduleTarget(day);
    }
    return null;
  }
}

/// The schedule page on [day] (date only).
class ScheduleTarget extends ReminderTarget {
  ScheduleTarget(DateTime day) : day = DateTime(day.year, day.month, day.day);

  final DateTime day;

  @override
  String encode() {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'schedule:${day.year}-${two(day.month)}-${two(day.day)}';
  }

  @override
  bool operator ==(Object other) => other is ScheduleTarget && other.day == day;

  @override
  int get hashCode => day.hashCode;
}

class HomeTarget extends ReminderTarget {
  const HomeTarget();

  @override
  String encode() => 'home';

  @override
  bool operator ==(Object other) => other is HomeTarget;

  @override
  int get hashCode => 0;
}
