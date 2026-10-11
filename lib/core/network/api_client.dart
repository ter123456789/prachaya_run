import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'token_store.dart';

/// The server answered with an error (`{ "error": { code, message } }`).
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.message = '']);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// The server could not be reached (offline, DNS, timeout).
class NetworkException implements Exception {
  const NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException($cause)';
}

/// JSON client for rinning_API (contract: rinning_API/docs/api.md).
///
/// Adds the access token, refreshes it once on `token_expired` (one refresh
/// at a time, shared by parallel calls) and signs out when the server
/// rejects the session.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokens,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokens = tokens,
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final TokenStore _tokens;
  final http.Client _http;
  final Duration timeout;
  final _sessionEnded = StreamController<void>.broadcast();
  Future<bool>? _refreshing;

  /// Fires when the server ended the session and the tokens were cleared.
  Stream<void> get sessionEnded => _sessionEnded.stream;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      send('GET', path, query: query);

  Future<Object?> post(
    String path,
    Object? body, {
    bool auth = true,
    bool gzipBody = false,
  }) => send('POST', path, body: body, auth: auth, gzipBody: gzipBody);

  Future<Object?> delete(String path) => send('DELETE', path);

  Future<Object?> send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    bool gzipBody = false,
  }) async {
    final bytes = body == null ? null : utf8.encode(jsonEncode(body));
    final payload = bytes != null && gzipBody ? gzip.encode(bytes) : bytes;

    String? usedToken;
    Future<http.Response> attempt() async {
      final headers = {
        'Accept': 'application/json',
        if (payload != null) 'Content-Type': 'application/json',
        if (payload != null && gzipBody) 'Content-Encoding': 'gzip',
      };
      if (auth) {
        final session = await _tokens.read();
        if (session == null) {
          throw const ApiException(401, 'unauthorized', 'signed out');
        }
        usedToken = session.accessToken;
        headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll(headers);
      if (payload != null) request.bodyBytes = payload;
      return _execute(request);
    }

    var response = await attempt();
    if (auth && _errorCode(response) == 'token_expired') {
      // Another call may have refreshed meanwhile: retry with its token
      // instead of refreshing again (the server rotates refresh tokens).
      final current = (await _tokens.read())?.accessToken;
      if (current == usedToken && !await _refresh()) {
        throw const ApiException(401, 'unauthorized', 'session ended');
      }
      response = await attempt();
    }
    if (auth && _errorCode(response) == 'unauthorized') await _endSession();
    return _decode(response);
  }

  Uri _uri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _execute(http.BaseRequest request) async {
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on IOException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    }
  }

  /// Returns whether new tokens were stored.
  Future<bool> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final session = await _tokens.read();
    if (session == null) return false;
    final request = http.Request('POST', _uri('/auth/refresh', null))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({'refreshToken': session.refreshToken});
    final response = await _execute(request);
    if (response.statusCode == 401) {
      await _endSession();
      return false;
    }
    final json = _decode(response)! as Map<String, Object?>;
    await _tokens.write(StoredSession.fromAuthJson(json));
    return true;
  }

  Future<void> _endSession() async {
    await _tokens.clear();
    _sessionEnded.add(null);
  }

  static String? _errorCode(http.Response response) {
    if (response.statusCode != 401) return null;
    return _parseError(response).code;
  }

  static Object? _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    throw _parseError(response);
  }

  static ApiException _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, Object?>;
      final error = json['error']! as Map<String, Object?>;
      return ApiException(
        response.statusCode,
        error['code']! as String,
        error['message'] as String? ?? '',
      );
    } catch (_) {
      return ApiException(response.statusCode, 'http_${response.statusCode}');
    }
  }
}
