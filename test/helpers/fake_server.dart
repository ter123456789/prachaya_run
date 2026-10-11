import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for rinning_API that follows docs/api.md closely
/// enough to exercise the client: auth tokens, upsert with last-write-wins,
/// soft delete and the updatedSince feed.
class FakeServer {
  final Map<String, Map<String, Object?>> activities = {};
  final List<http.BaseRequest> requests = [];
  final List<Map<String, Object?>> uploads = [];
  String validAccessToken = 'access-1';
  String validRefreshToken = 'refresh-1';
  bool offline = false;
  int _clock = 0;

  late final client = MockClient(_handle);

  /// Adds an activity as if another device had uploaded it.
  void seed(Map<String, Object?> body) => activities[body['id']! as String] = {
    ...body,
    'distanceM': 1000.0,
    'elevationGainM': 5.0,
    'deletedAt': null,
    '_serverUpdatedAt': ++_clock,
  };

  void softDelete(String id) {
    activities[id]!['deletedAt'] = '2026-10-12T00:00:00.000Z';
    activities[id]!['_serverUpdatedAt'] = ++_clock;
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline');
    final path = request.url.path;

    if (path == '/auth/refresh') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (body['refreshToken'] != validRefreshToken) {
        return _error(401, 'unauthorized');
      }
      validAccessToken = 'access-${++_clock}';
      validRefreshToken = 'refresh-$_clock';
      return _json(200, {
        'accessToken': validAccessToken,
        'refreshToken': validRefreshToken,
        'user': {'id': 'u1', 'email': 'a@b.co'},
      });
    }

    final auth = request.headers['Authorization'];
    if (auth != 'Bearer $validAccessToken') {
      return _error(401, 'token_expired');
    }

    if (path == '/activities' && request.method == 'POST') {
      final raw = request.headers['Content-Encoding'] == 'gzip'
          ? utf8.decode(gzip.decode(request.bodyBytes))
          : request.body;
      final body = jsonDecode(raw) as Map<String, Object?>;
      uploads.add(body);
      final id = body['id']! as String;
      final stored = activities[id];
      if (stored != null &&
          (stored['deletedAt'] != null ||
              (body['updatedAt']! as String).compareTo(
                    stored['updatedAt']! as String,
                  ) <
                  0)) {
        return _json(200, _summary(stored));
      }
      seed(body);
      return _json(200, _summary(activities[id]!));
    }

    if (path == '/activities' && request.method == 'GET') {
      final since = request.url.queryParameters['updatedSince']!;
      final sinceClock = since.startsWith('1970') ? 0 : int.parse(since);
      final items = activities.values
          .where((a) => (a['_serverUpdatedAt']! as int) > sinceClock)
          .map(_summary)
          .toList();
      return _json(200, {
        'items': items,
        'nextCursor': null,
        'serverTime': '$_clock',
      });
    }

    final id = path.split('/').last;
    final stored = activities[id];
    if (request.method == 'DELETE') {
      if (stored != null) softDelete(id);
      return http.Response('', 204);
    }
    if (stored == null || stored['deletedAt'] != null) {
      return _error(404, 'not_found');
    }
    return _json(200, {..._summary(stored), 'segments': stored['segments']});
  }

  static Map<String, Object?> _summary(Map<String, Object?> a) => {
    for (final e in a.entries)
      if (e.key != 'segments' && !e.key.startsWith('_')) e.key: e.value,
  };

  static http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response _error(int status, String code) => _json(status, {
    'error': {'code': code, 'message': code},
  });
}
