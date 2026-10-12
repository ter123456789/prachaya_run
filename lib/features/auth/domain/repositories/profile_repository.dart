import '../entities/user_profile.dart';
import '../services/profile_validation.dart';

abstract interface class ProfileRepository {
  /// The profile of whoever uses the app now: the signed-in account's, or
  /// the device's own when signed out. Works offline.
  Future<UserProfile> load();

  /// Replaces the whole profile, saves it on the device and syncs it when
  /// signed in. Throws [ProfileValidationException] for out-of-range values.
  Future<UserProfile> save(UserProfile profile);
}
