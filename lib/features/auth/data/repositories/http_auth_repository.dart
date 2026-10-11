import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, this._tokens) {
    _api.sessionEnded.listen((_) => _changes.add(null));
  }

  final ApiClient _api;
  final TokenStore _tokens;
  final _changes = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser?> currentUser() async {
    final session = await _tokens.read();
    return session == null ? null : _user(session);
  }

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _signIn('/auth/login', email, password);

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => _signIn('/auth/register', email, password);

  @override
  Future<void> logout() async {
    final session = await _tokens.read();
    await _tokens.clear();
    _changes.add(null);
    if (session == null) return;
    try {
      await _api.post('/auth/logout', {
        'refreshToken': session.refreshToken,
      }, auth: false);
    } catch (_) {
      // Signed out locally either way; the token expires on its own.
    }
  }

  Future<AuthUser> _signIn(String path, String email, String password) async {
    try {
      final json =
          await _api.post(path, {
                'email': email.trim(),
                'password': password,
              }, auth: false)
              as Map<String, Object?>;
      final session = StoredSession.fromAuthJson(json);
      await _tokens.write(session);
      final user = _user(session);
      _changes.add(user);
      return user;
    } on ApiException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid_credentials' => AuthError.invalidCredentials,
        'email_taken' => AuthError.emailTaken,
        'validation_error' => AuthError.invalidInput,
        _ => AuthError.unknown,
      });
    } on NetworkException {
      throw const AuthException(AuthError.network);
    }
  }

  static AuthUser _user(StoredSession s) =>
      AuthUser(id: s.userId, email: s.email);
}
