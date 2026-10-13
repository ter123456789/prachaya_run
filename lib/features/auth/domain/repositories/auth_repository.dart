import '../entities/auth_user.dart';

enum AuthError {
  invalidCredentials,
  emailTaken,
  invalidInput,
  network,

  /// The user closed the Apple/Google sheet: not an error to show.
  cancelled,

  /// The provider is not set up (on this device or on the server).
  providerUnavailable,
  unknown,
}

/// Sign in with Apple / Google (api.md v1.3).
enum SocialProvider { apple, google }

class AuthException implements Exception {
  const AuthException(this.error);

  final AuthError error;

  @override
  String toString() => 'AuthException($error)';
}

abstract interface class AuthRepository {
  /// The account kept from the last session, or null.
  Future<AuthUser?> currentUser();

  /// Emits whenever the account changes, including when the server ends the
  /// session (refresh token expired or revoked) and the user is signed out.
  Stream<AuthUser?> get userChanges;

  /// Throws [AuthException].
  Future<AuthUser> login({required String email, required String password});

  /// Throws [AuthException].
  Future<AuthUser> register({required String email, required String password});

  /// Providers this build and device can offer (Apple on iOS; Google once
  /// its client ids are configured).
  Future<Set<SocialProvider>> availableProviders();

  /// Signs in or up with the provider's account. Throws [AuthException]
  /// ([AuthError.cancelled] when the user backs out).
  Future<AuthUser> signInWith(SocialProvider provider);

  /// Always signs out locally, even when the server cannot be reached.
  Future<void> logout();

  /// Permanently deletes the account and its data on the server, then its
  /// data on this device. Throws [AuthException] (nothing is deleted when
  /// the server cannot be reached).
  Future<void> deleteAccount();
}
