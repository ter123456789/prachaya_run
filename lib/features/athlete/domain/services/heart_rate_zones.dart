// Heart-rate zones from Max HR, five bands of 10 % each (50–100 %).
//
// Max HR is the user's own value when set, otherwise the Tanaka estimate
// `208 − 0.7 × age` (Tanaka, Monahan & Seals, 2001).

enum MaxHrSource { entered, tanaka }

class MaxHeartRate {
  const MaxHeartRate(this.bpm, this.source);

  final int bpm;
  final MaxHrSource source;

  @override
  bool operator ==(Object other) =>
      other is MaxHeartRate && other.bpm == bpm && other.source == source;

  @override
  int get hashCode => Object.hash(bpm, source);
}

class HeartRateZone {
  const HeartRateZone({
    required this.number,
    required this.lowBpm,
    required this.highBpm,
    required this.lowPercent,
    required this.highPercent,
  });

  /// 1–5.
  final int number;
  final int lowBpm;

  /// Inclusive; the top zone ends at Max HR.
  final int highBpm;
  final int lowPercent;
  final int highPercent;

  @override
  bool operator ==(Object other) =>
      other is HeartRateZone &&
      other.number == number &&
      other.lowBpm == lowBpm &&
      other.highBpm == highBpm;

  @override
  int get hashCode => Object.hash(number, lowBpm, highBpm);

  @override
  String toString() => 'Z$number $lowBpm–$highBpm';
}

/// Whole years old on [today]'s year (birthday not known, only the year).
int? ageIn(int? birthYear, DateTime today) =>
    birthYear == null ? null : today.year - birthYear;

/// `208 − 0.7 × age`, rounded.
int tanakaMaxHr(int age) => (208 - 0.7 * age).round();

/// The user's value wins; otherwise Tanaka from the birth year. Null when
/// neither is known.
MaxHeartRate? resolveMaxHr({
  int? enteredBpm,
  int? birthYear,
  required DateTime today,
}) {
  if (enteredBpm != null) return MaxHeartRate(enteredBpm, MaxHrSource.entered);
  final age = ageIn(birthYear, today);
  if (age == null) return null;
  return MaxHeartRate(tanakaMaxHr(age), MaxHrSource.tanaka);
}

/// Zone n covers (40 + 10n) % – (50 + 10n) % of [maxHr]. Each zone starts at
/// the first whole bpm at or above its lower bound and ends one bpm below
/// the next zone, so the bands never overlap. For Max HR 191:
/// 96–114, 115–133, 134–152, 153–171, 172–191.
List<HeartRateZone> heartRateZones(int maxHr) {
  // Integer ceiling of pct % of maxHr, without floating-point error.
  int ceilPercent(int pct) => (pct * maxHr + 99) ~/ 100;
  return [
    for (var n = 1; n <= 5; n++)
      HeartRateZone(
        number: n,
        lowPercent: 40 + 10 * n,
        highPercent: 50 + 10 * n,
        lowBpm: ceilPercent(40 + 10 * n),
        highBpm: n == 5 ? maxHr : ceilPercent(50 + 10 * n) - 1,
      ),
  ];
}
