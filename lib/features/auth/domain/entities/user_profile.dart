/// The runner's own details. Kept on the device (works without an account)
/// and synced to `/me` once signed in.
class UserProfile {
  const UserProfile({
    this.displayName,
    this.weightKg,
    this.heightCm,
    this.birthYear,
    this.maxHrBpm,
  });

  final String? displayName;

  /// Used for calorie estimates and BMI.
  final double? weightKg;
  final double? heightCm;

  /// Age for the Tanaka Max HR estimate.
  final int? birthYear;

  /// User-entered Max HR; overrides the age estimate.
  final int? maxHrBpm;

  bool get isEmpty =>
      displayName == null &&
      weightKg == null &&
      heightCm == null &&
      birthYear == null &&
      maxHrBpm == null;

  /// Fields set here win; null ones keep [other]'s value.
  UserProfile mergedOver(UserProfile other) => UserProfile(
    displayName: displayName ?? other.displayName,
    weightKg: weightKg ?? other.weightKg,
    heightCm: heightCm ?? other.heightCm,
    birthYear: birthYear ?? other.birthYear,
    maxHrBpm: maxHrBpm ?? other.maxHrBpm,
  );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.weightKg == weightKg &&
      other.heightCm == heightCm &&
      other.birthYear == birthYear &&
      other.maxHrBpm == maxHrBpm;

  @override
  int get hashCode =>
      Object.hash(displayName, weightKg, heightCm, birthYear, maxHrBpm);

  @override
  String toString() =>
      'UserProfile($displayName, $weightKg kg, $heightCm cm, '
      'born $birthYear, max HR $maxHrBpm)';
}
