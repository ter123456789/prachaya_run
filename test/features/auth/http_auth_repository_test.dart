import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/features/auth/data/repositories/http_auth_repository.dart';
import 'package:prachaya_run/features/auth/data/services/social_credentials.dart';
import 'package:prachaya_run/features/auth/domain/repositories/auth_repository.dart';

import '../../helpers/memory_token_store.dart';

void main() {
  late List<http.Request> requests;
  late MemoryTokenStore tokens;

  HttpAuthRepository repo(
    http.Response Function(http.Request) handler, {
    SocialCredentialSource? social,
  }) {
    requests = [];
    tokens = MemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'http://api.test/',
      tokens: tokens,
      httpClient: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
    return HttpAuthRepository(api, tokens, social: social);
  }

  http.Response json(int status, Object body) =>
      http.Response(jsonEncode(body), status);

  test('login stores the session', () async {
    final r = repo(
      (_) => json(200, {
        'accessToken': 'a',
        'refreshToken': 'r',
        'user': {'id': 'u1', 'email': 'a@b.co'},
      }),
    );
    final user = await r.login(email: ' a@b.co ', password: 'password1');

    expect(user.id, 'u1');
    expect(tokens.session!.refreshToken, 'r');
    expect(requests.single.url.toString(), 'http://api.test/auth/login');
    expect(jsonDecode(requests.single.body), {
      'email': 'a@b.co',
      'password': 'password1',
    });
    expect(await r.currentUser(), user);
  });

  test('error codes become AuthErrors', () async {
    final r = repo(
      (_) => json(401, {
        'error': {'code': 'invalid_credentials', 'message': ''},
      }),
    );
    await expectLater(
      r.login(email: 'a@b.co', password: 'password1'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.invalidCredentials,
        ),
      ),
    );
  });

  test('logout clears locally even when the server is unreachable', () async {
    final r = repo((_) => throw http.ClientException('offline'));
    await tokens.write(StoredSessionFixture.session);
    final changes = <Object?>[];
    r.userChanges.listen(changes.add);

    await r.logout();
    await Future<void>.delayed(Duration.zero);

    expect(tokens.session, isNull);
    expect(changes, [null]);
    expect(requests.single.url.path, '/auth/logout');
  });

  test('deleteAccount calls DELETE /me, cleans up and signs out', () async {
    String? purged;
    requests = [];
    tokens = MemoryTokenStore(StoredSessionFixture.session);
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokens: tokens,
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('', 204);
      }),
    );
    final r = HttpAuthRepository(
      api,
      tokens,
      onAccountDeleted: (id) async => purged = id,
    );
    final changes = <Object?>[];
    r.userChanges.listen(changes.add);

    await r.deleteAccount();
    await Future<void>.delayed(Duration.zero);

    expect(requests.single.method, 'DELETE');
    expect(requests.single.url.path, '/me');
    expect(requests.single.headers['Authorization'], 'Bearer a');
    expect(purged, 'u1');
    expect(tokens.session, isNull);
    expect(changes, [null]);
  });

  test('deleteAccount offline keeps the account and reports network', () async {
    final r = repo((_) => throw http.ClientException('offline'));
    await tokens.write(StoredSessionFixture.session);
    await expectLater(
      r.deleteAccount(),
      throwsA(
        isA<AuthException>().having((e) => e.error, 'error', AuthError.network),
      ),
    );
    expect(tokens.session, isNotNull);
  });

  group('social sign-in (api.md v1.3)', () {
    Map<String, Object?> authBody() => {
      'accessToken': 'a',
      'refreshToken': 'r',
      'user': {'id': 'u9', 'email': 'runner@icloud.com'},
      'created': true,
    };

    test('Apple sends the identity token and first-time name', () async {
      final r = repo(
        (_) => json(200, authBody()),
        social: _FakeSocial(
          const SocialCredential('apple-jwt', fullName: 'Prachaya R'),
        ),
      );
      final user = await r.signInWith(SocialProvider.apple);
      expect(user.email, 'runner@icloud.com');
      expect(tokens.session!.userId, 'u9');
      expect(requests.single.url.path, '/auth/apple');
      expect(requests.single.headers['authorization'], isNull);
      expect(jsonDecode(requests.single.body), {
        'identityToken': 'apple-jwt',
        'fullName': 'Prachaya R',
      });
    });

    test('Google sends its ID token; no name field', () async {
      final r = repo(
        (_) => json(200, authBody()),
        social: _FakeSocial(const SocialCredential('google-jwt')),
      );
      await r.signInWith(SocialProvider.google);
      expect(requests.single.url.path, '/auth/google');
      expect(jsonDecode(requests.single.body), {'idToken': 'google-jwt'});
    });

    test('closing the sheet is "cancelled" and calls no server', () async {
      final r = repo((_) => json(200, authBody()), social: _FakeSocial(null));
      await expectLater(
        r.signInWith(SocialProvider.apple),
        throwsA(
          isA<AuthException>().having(
            (e) => e.error,
            'error',
            AuthError.cancelled,
          ),
        ),
      );
      expect(requests, isEmpty);
      expect(tokens.session, isNull);
    });

    test('server without client ids → providerUnavailable', () async {
      final r = repo(
        (_) => json(503, {
          'error': {'code': 'provider_not_configured', 'message': ''},
        }),
        social: _FakeSocial(const SocialCredential('t')),
      );
      await expectLater(
        r.signInWith(SocialProvider.google),
        throwsA(
          isA<AuthException>().having(
            (e) => e.error,
            'error',
            AuthError.providerUnavailable,
          ),
        ),
      );
    });

    test('offers only the providers the device supports', () async {
      final r = repo(
        (_) => json(200, {}),
        social: _FakeSocial(null, available: {SocialProvider.apple}),
      );
      expect(await r.availableProviders(), {SocialProvider.apple});
      expect(await repo((_) => json(200, {})).availableProviders(), isEmpty);
    });
  });
}

abstract final class StoredSessionFixture {
  static const session = StoredSession(
    accessToken: 'a',
    refreshToken: 'r',
    userId: 'u1',
    email: 'a@b.co',
  );
}

class _FakeSocial implements SocialCredentialSource {
  _FakeSocial(this.credential, {this.available = const {}});

  /// Null: the user cancels.
  final SocialCredential? credential;
  final Set<SocialProvider> available;

  @override
  Future<bool> isAvailable(SocialProvider provider) async =>
      available.contains(provider);

  @override
  Future<SocialCredential> obtain(SocialProvider provider) async =>
      credential ?? (throw const SocialSignInCancelled());
}
