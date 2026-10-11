import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/features/auth/data/repositories/http_auth_repository.dart';
import 'package:prachaya_run/features/auth/domain/repositories/auth_repository.dart';

import '../../helpers/memory_token_store.dart';

void main() {
  late List<http.Request> requests;
  late MemoryTokenStore tokens;

  HttpAuthRepository repo(http.Response Function(http.Request) handler) {
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
    return HttpAuthRepository(api, tokens);
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
}

abstract final class StoredSessionFixture {
  static const session = StoredSession(
    accessToken: 'a',
    refreshToken: 'r',
    userId: 'u1',
    email: 'a@b.co',
  );
}
