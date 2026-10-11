class UserProfile {
  const UserProfile({this.displayName, this.weightKg});

  final String? displayName;

  /// Used for calorie estimates.
  final double? weightKg;

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(displayName, weightKg);
}
