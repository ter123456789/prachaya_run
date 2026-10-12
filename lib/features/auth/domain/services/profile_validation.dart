import '../entities/user_profile.dart';

/// Profile fields that can be out of range (docs/api.md, `PATCH /me`).
enum ProfileField { displayName, weightKg, heightCm, birthYear, maxHrBpm }

class ProfileValidationException implements Exception {
  const ProfileValidationException(this.fields);

  final Set<ProfileField> fields;

  @override
  String toString() => 'ProfileValidationException($fields)';
}

/// The same limits the server enforces, so a saved profile always syncs.
Set<ProfileField> validateProfile(UserProfile p, {required int currentYear}) {
  final name = p.displayName;
  return {
    if (name != null && (name.trim().isEmpty || name.trim().length > 40))
      ProfileField.displayName,
    if (p.weightKg case final w? when w < 20 || w > 300) ProfileField.weightKg,
    if (p.heightCm case final h? when h < 100 || h > 250) ProfileField.heightCm,
    if (p.birthYear case final y? when y < 1900 || y > currentYear - 5)
      ProfileField.birthYear,
    if (p.maxHrBpm case final m? when m < 100 || m > 230) ProfileField.maxHrBpm,
  };
}
