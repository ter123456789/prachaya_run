import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/repositories/auth_repository.dart';

/// A provider's ID token for `POST /auth/apple` or `/auth/google`.
class SocialCredential {
  const SocialCredential(this.idToken, {this.fullName});

  final String idToken;

  /// Apple sends the name only on the first sign-in.
  final String? fullName;
}

/// The user closed the provider's sheet.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

/// Talks to the platform sign-in SDKs.
abstract interface class SocialCredentialSource {
  Future<bool> isAvailable(SocialProvider provider);

  /// Throws [SocialSignInCancelled], or anything else on failure.
  Future<SocialCredential> obtain(SocialProvider provider);
}

/// Google client ids, set at build time (empty = Google hidden):
/// `--dart-define=GOOGLE_CLIENT_ID=<iOS client id>` and
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (Android).
/// iOS also needs `GIDClientID` and the reversed client id URL scheme in
/// Info.plist.
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class PluginSocialCredentialSource implements SocialCredentialSource {
  Future<void>? _googleReady;

  bool get _googleConfigured => Platform.isIOS
      ? _googleClientId.isNotEmpty
      : Platform.isAndroid && _googleServerClientId.isNotEmpty;

  @override
  Future<bool> isAvailable(SocialProvider provider) async {
    return switch (provider) {
      SocialProvider.apple =>
        Platform.isIOS && await SignInWithApple.isAvailable(),
      SocialProvider.google => _googleConfigured,
    };
  }

  @override
  Future<SocialCredential> obtain(SocialProvider provider) =>
      switch (provider) {
        SocialProvider.apple => _apple(),
        SocialProvider.google => _google(),
      };

  Future<SocialCredential> _apple() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = c.identityToken;
      if (token == null) throw StateError('no identity token');
      final name = [
        c.givenName,
        c.familyName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      return SocialCredential(token, fullName: name.isEmpty ? null : name);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
  }

  Future<SocialCredential> _google() async {
    final google = GoogleSignIn.instance;
    await (_googleReady ??= google.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    ));
    try {
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw StateError('no id token');
      return SocialCredential(token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
  }
}
