import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's profile: cached copy first, refreshed from the
  /// server when reachable. Null when signed out.
  Future<UserProfile?> load();

  /// Throws [ProfileUpdateException] when the server rejects or is
  /// unreachable.
  Future<UserProfile> update({
    String? displayName,
    double? weightKg,
    bool clearWeight = false,
  });
}

class ProfileUpdateException implements Exception {
  const ProfileUpdateException({this.offline = false});

  final bool offline;
}
