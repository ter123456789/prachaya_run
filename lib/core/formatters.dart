import 'units/distance_unit.dart';

/// Distance in [unit] with two decimals, e.g. `5.32`.
String formatDistance(double meters, DistanceUnit unit) =>
    unit.fromMeters(meters).toStringAsFixed(2);

String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Strava-style compact duration: `38m 14s`, `1h 05m`.
String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m ${s}s';
}

/// Minutes per [unit], e.g. `5:32`; `--:--` when standing still.
String formatPaceIn(double speedMps, DistanceUnit unit) {
  final seconds = unit.secondsPerUnit(speedMps);
  return seconds == null ? '--:--' : formatPaceSeconds(seconds);
}

/// `m:ss` from a pace in seconds, e.g. 315 → `5:15`.
String formatPaceSeconds(num seconds) {
  final total = seconds.round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Telemetry style `5'15"` from a pace in seconds.
String formatPaceSecondsQuote(num seconds) {
  final total = seconds.round();
  return "${total ~/ 60}'${(total % 60).toString().padLeft(2, '0')}\"";
}

/// Speed in [unit] per hour with one decimal.
String formatSpeedIn(double speedMps, DistanceUnit unit) =>
    unit.perHour(speedMps).toStringAsFixed(1);

const _thaiMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// e.g. `9 ต.ค. 2569 · 06:30`
String formatDateTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_thaiMonths[t.month - 1]} ${t.year + 543} · $hh:$mm';
}

/// ตอนเช้า / ตอนบ่าย / ตอนเย็น / ตอนค่ำ
String timeOfDayPeriod(DateTime t) => switch (t.hour) {
  >= 5 && < 12 => 'ตอนเช้า',
  >= 12 && < 17 => 'ตอนบ่าย',
  >= 17 && < 20 => 'ตอนเย็น',
  _ => 'ตอนค่ำ',
};

/// e.g. `เมื่อสักครู่`, `25 นาทีที่แล้ว`, `3 ชม.ที่แล้ว`, `เมื่อวาน`, `4 วันที่แล้ว`
String formatRelative(DateTime t, DateTime now) {
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inDays < 1) return '${diff.inHours} ชม.ที่แล้ว';
  if (diff.inDays == 1) return 'เมื่อวาน';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return formatDateTime(t).split(' · ').first;
}

const _thaiMonthsFull = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

/// e.g. `ตุลาคม 2569`
String formatMonthYear(DateTime t) =>
    '${_thaiMonthsFull[t.month - 1]} ${t.year + 543}';

const _thaiWeekdaysShort = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
const _thaiWeekdays = [
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
  'อาทิตย์',
];

/// `จ.` … `อา.`
String thaiWeekdayShort(DateTime t) => _thaiWeekdaysShort[t.weekday - 1];

/// `จันทร์` … `อาทิตย์`
String thaiWeekday(DateTime t) => _thaiWeekdays[t.weekday - 1];

/// e.g. `16 พ.ค.`
String formatDayMonth(DateTime t) => '${t.day} ${_thaiMonths[t.month - 1]}';

/// e.g. `พฤหัสบดี 16 พ.ค. 2569`
String formatLongDate(DateTime t) =>
    '${thaiWeekday(t)} ${formatDayMonth(t)} ${t.year + 543}';

/// e.g. `18:30`
String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
