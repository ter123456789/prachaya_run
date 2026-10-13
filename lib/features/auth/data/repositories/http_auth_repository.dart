import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/social_credentials.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(
    this._api,
    this._tokens, {
    SocialCredentialSource? social,
    Future<void> Function(String userId)? onAccountDeleted,
  }) : _social = social,
       _onAccountDeleted = onAccountDeleted {
    _api.sessionEnded.listen((_) => _changes.add(null));
  }

  final ApiClient _api;
  final TokenStore _tokens;
  final SocialCredentialSource? _social;

  /// Removes the account's rows and files from this device.
  final Future<void> Function(String userId)? _onAccountDeleted;
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

  /// Providers this device supports that the server has client ids for.
  /// The server is asked with a junk token (api.md v1.3, "Availability"):
  /// 401 means set up, 503 `provider_not_configured` means not. Offline,
  /// none are offered (signing in needs the server anyway).
  @override
  Future<Set<SocialProvider>> availableProviders() async {
    final social = _social;
    if (social == null) return const {};
    final result = <SocialProvider>{};
    for (final p in SocialProvider.values) {
      if (!await social.isAvailable(p)) continue;
      try {
        await _api.post(_path(p), _body(p, 'probe'), auth: false);
        result.add(p);
      } on ApiException catch (e) {
        if (e.code != 'provider_not_configured') result.add(p);
      } on NetworkException {
        // Not offered while offline.
      }
    }
    return result;
  }

  static String _path(SocialProvider p) => switch (p) {
    SocialProvider.apple => '/auth/apple',
    SocialProvider.google => '/auth/google',
  };

  static Map<String, Object?> _body(
    SocialProvider p,
    String token, {
    String? fullName,
  }) => switch (p) {
    SocialProvider.apple => {'identityToken': token, 'fullName': ?fullName},
    SocialProvider.google => {'idToken': token},
  };

  @override
  Future<AuthUser> signInWith(SocialProvider provider) async {
    final social = _social;
    if (social == null) {
      throw const AuthException(AuthError.providerUnavailable);
    }
    final SocialCredential credential;
    try {
      credential = await social.obtain(provider);
    } on SocialSignInCancelled {
      throw const AuthException(AuthError.cancelled);
    } catch (_) {
      throw const AuthException(AuthError.unknown);
    }
    return _authenticate(
      switch (provider) {
        SocialProvider.apple => '/auth/apple',
        SocialProvider.google => '/auth/google',
      },
      switch (provider) {
        SocialProvider.apple => {
          'identityToken': credential.idToken,
          'fullName': ?credential.fullName,
        },
        SocialProvider.google => {'idToken': credential.idToken},
      },
    );
  }

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

  @override
  Future<void> deleteAccount() async {
    final session = await _tokens.read();
    if (session == null) return;
    try {
      await _api.delete('/me');
    } on NetworkException {
      throw const AuthException(AuthError.network);
    } on ApiException catch (e) {
      // Already gone (e.g. deleted on another device): finish locally.
      if (e.status != 401 && e.status != 404) {
        throw const AuthException(AuthError.unknown);
      }
    }
    await _onAccountDeleted?.call(session.userId);
    await _tokens.clear();
    _changes.add(null);
  }

  Future<AuthUser> _signIn(String path, String email, String password) =>
      _authenticate(path, {'email': email.trim(), 'password': password});

  Future<AuthUser> _authenticate(String path, Map<String, Object?> body) async {
    try {
      final json =
          await _api.post(path, body, auth: false) as Map<String, Object?>;
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
        'provider_not_configured' => AuthError.providerUnavailable,
        // The server could not reach Apple's / Google's keys: retry later.
        'provider_unavailable' => AuthError.network,
        _ => AuthError.unknown,
      });
    } on NetworkException {
      throw const AuthException(AuthError.network);
    }
  }

  static AuthUser _user(StoredSession s) =>
      AuthUser(id: s.userId, email: s.email);
}
