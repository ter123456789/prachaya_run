import '../entities/auth_user.dart';

enum AuthError {
  invalidCredentials,
  emailTaken,
  invalidInput,
  network,
  unknown,
}

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

  /// Always signs out locally, even when the server cannot be reached.
  Future<void> logout();
}
