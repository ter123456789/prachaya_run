import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prachaya_run/core/network/api_client.dart';
import 'package:prachaya_run/core/network/token_store.dart';
import 'package:prachaya_run/features/auth/data/repositories/http_account_link_repository.dart';
import 'package:prachaya_run/features/auth/domain/entities/linked_accounts.dart';
import 'package:prachaya_run/features/auth/domain/repositories/account_link_repository.dart';

import '../../../helpers/memory_token_store.dart';

void main() {
  late List<http.Request> requests;

  HttpAccountLinkRepository repo(
    http.Response Function(http.Request) handler, {
    bool signedIn = true,
  }) {
    requests = [];
    final tokens = MemoryTokenStore(
      signedIn
          ? const StoredSession(
              accessToken: 'a',
              refreshToken: 'r',
              userId: 'u1',
              email: 'a@b.co',
            )
          : null,
    );
    final api = ApiClient(
      baseUrl: 'http://api.test',
      tokens: tokens,
      httpClient: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
    return HttpAccountLinkRepository(api, tokens);
  }

  http.Response json(int status, Object body) =>
      http.Response(jsonEncode(body), status);

  test('reads GET /me/links (v1.6), skipping unknown providers', () async {
    final r = repo(
      (_) => json(200, {
        'available': ['polar', 'suunto'],
        'items': [
          {
            'provider': 'polar',
            'status': 'ok',
            'linkedAt': '2026-10-27T10:00:00.000Z',
            'lastImportAt': null,
          },
        ],
      }),
    );
    final accounts = await r.load();
    expect(accounts.available, [LinkProvider.polar]);
    expect(accounts.links.single.status, LinkStatus.ok);
    expect(requests.single.url.path, '/me/links');
  });

  test('signed out: nothing is asked', () async {
    final r = repo((_) => json(500, {}), signedIn: false);
    expect((await r.load()).available, isEmpty);
    expect(requests, isEmpty);
  });

  test('start returns the authorize URL; 503 means unavailable', () async {
    final ok = repo(
      (_) => json(200, {'authorizeUrl': 'https://flow.polar.com/oauth2/x'}),
    );
    expect(
      (await ok.start(LinkProvider.polar)).toString(),
      'https://flow.polar.com/oauth2/x',
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/me/links/polar');

    final down = repo(
      (_) => json(503, {
        'error': {'code': 'provider_not_configured', 'message': ''},
      }),
    );
    expect(
      () => down.start(LinkProvider.polar),
      throwsA(isA<AccountLinkUnavailable>()),
    );
  });

  test('sync and unlink hit their endpoints', () async {
    final r = repo(
      (req) => http.Response('', req.method == 'DELETE' ? 204 : 202),
    );
    await r.sync(LinkProvider.polar);
    await r.unlink(LinkProvider.polar);
    expect(requests.map((q) => '${q.method} ${q.url.path}'), [
      'POST /me/links/polar/sync',
      'DELETE /me/links/polar',
    ]);
  });
}
