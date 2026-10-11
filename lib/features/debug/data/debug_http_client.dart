import 'dart:convert';

import 'package:http/http.dart' as http;

/// Wraps the app's HTTP client to fake network conditions in debug builds.
class DebugHttpClient extends http.BaseClient {
  DebugHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// Fail every request like a dropped connection.
  bool offline = false;

  /// Answer the next authenticated (non-/auth) request with
  /// `401 token_expired` without sending it.
  bool expireNext = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('debug: offline', request.url);
    final authed =
        request.headers.containsKey('Authorization') &&
        !request.url.path.startsWith('/auth/');
    if (expireNext && authed) {
      expireNext = false;
      final body = utf8.encode(
        jsonEncode({
          'error': {'code': 'token_expired', 'message': 'debug'},
        }),
      );
      return http.StreamedResponse(
        Stream.value(body),
        401,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    return _inner.send(request);
  }
}
