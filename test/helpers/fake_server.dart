import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for rinning_API that follows docs/api.md closely
/// enough to exercise the client: auth tokens, upsert with last-write-wins,
/// soft delete and the updatedSince feed.
class FakeServer {
  final Map<String, Map<String, Object?>> activities = {};
  final List<http.BaseRequest> requests = [];
  final List<Map<String, Object?>> uploads = [];

  /// v1.2 records by resource (`shoes`, `workouts`): id → API object plus
  /// `_serverUpdatedAt`.
  final Map<String, Map<String, Map<String, Object?>>> records = {
    'shoes': {},
    'workouts': {},
  };

  /// photoId → {activityId, takenAt, bytes}
  final Map<String, Map<String, Object?>> photos = {};
  Map<String, Object?> profile = {
    'id': 'u1',
    'email': 'a@b.co',
    'displayName': null,
    'weightKg': null,
    'heightCm': null,
    'birthYear': null,
    'maxHrBpm': null,
  };
  String validAccessToken = 'access-1';
  String validRefreshToken = 'refresh-1';
  bool offline = false;
  bool accountDeleted = false;
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

  /// Adds a photo as if another device had uploaded it.
  void seedPhoto(String activityId, String photoId, List<int> bytes) {
    photos[photoId] = {
      'activityId': activityId,
      'takenAt': '2026-10-11T07:00:00.000Z',
      'bytes': bytes,
    };
    activities[activityId]!['_serverUpdatedAt'] = ++_clock;
  }

  /// Adds a shoe or workout as if another device had saved it.
  void seedRecord(String resource, Map<String, Object?> body) =>
      records[resource]![body['id']! as String] = {
        ...body,
        'deletedAt': null,
        '_serverUpdatedAt': ++_clock,
      };

  List<Map<String, Object?>> live(String resource) => [
    for (final r in records[resource]!.values)
      if (r['deletedAt'] == null) _public(r),
  ];

  int _photoCount(String activityId) =>
      photos.values.where((p) => p['activityId'] == activityId).length;

  void softDelete(String id) {
    activities[id]!['deletedAt'] = '2026-10-12T00:00:00.000Z';
    activities[id]!['_serverUpdatedAt'] = ++_clock;
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline');
    final path = request.url.path;

    if (request.url.host == 'files.test') {
      final photo = photos[path.substring(1)];
      return photo == null
          ? http.Response('', 404)
          : http.Response.bytes(photo['bytes']! as List<int>, 200);
    }

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

    if (path == '/me') {
      if (request.method == 'DELETE') {
        accountDeleted = true;
        activities.clear();
        photos.clear();
        validAccessToken = 'revoked';
        validRefreshToken = 'revoked';
        return http.Response('', 204);
      }
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        profile = {...profile, ...body};
      }
      return _json(200, profile);
    }

    final record = RegExp(r'^/(shoes|workouts)(?:/([^/]+))?$').firstMatch(path);
    if (record != null) {
      return _record(request, record.group(1)!, record.group(2));
    }

    if (path == '/challenges/current') {
      return _json(200, {
        'id': '2026-10',
        'title': 'ความท้าทายประจำเดือนตุลาคม',
        'badge': 'Night Owl',
        'goalM': 20000,
        'progressM': 0,
        'startsAt': '2026-09-30T17:00:00.000Z',
        'endsAt': '2026-10-31T17:00:00.000Z',
        'completed': false,
      });
    }

    final photoMatch = RegExp(
      r'^/activities/([^/]+)/photos(?:/([^/]+))?$',
    ).firstMatch(path);
    if (photoMatch != null) {
      final activityId = photoMatch.group(1)!;
      final photoId = photoMatch.group(2);
      final activity = activities[activityId];
      if (request.method == 'DELETE') {
        if (photos.remove(photoId) != null) {
          activity?['_serverUpdatedAt'] = ++_clock;
        }
        return http.Response('', 204);
      }
      if (activity == null || activity['deletedAt'] != null) {
        return _error(404, 'not_found');
      }
      if (request.method == 'PUT') {
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        photos[photoId!] = {
          'activityId': activityId,
          'takenAt': '2026-10-11T07:00:00.000Z',
          'bytes': request.bodyBytes,
        };
        activity['_serverUpdatedAt'] = ++_clock;
        return _json(200, {'id': photoId, 'activityId': activityId});
      }
      return _json(200, {
        'items': [
          for (final e in photos.entries)
            if (e.value['activityId'] == activityId)
              {
                'id': e.key,
                'url': 'https://files.test/${e.key}?sig=${++_clock}',
                'takenAt': e.value['takenAt'],
              },
        ],
      });
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
      if (stored != null) {
        softDelete(id);
        photos.removeWhere((_, p) => p['activityId'] == id);
      }
      return http.Response('', 204);
    }
    if (stored == null || stored['deletedAt'] != null) {
      return _error(404, 'not_found');
    }
    return _json(200, {..._summary(stored), 'segments': stored['segments']});
  }

  /// docs/api.md v1.2: upsert with last-write-wins, soft delete, feed.
  http.Response _record(http.Request request, String resource, String? id) {
    final store = records[resource]!;
    if (id == null) {
      final since = request.url.queryParameters['updatedSince'];
      final sinceClock = since == null || since.startsWith('1970')
          ? 0
          : int.parse(since);
      return _json(200, {
        'items': [
          for (final r in store.values)
            if ((r['_serverUpdatedAt']! as int) > sinceClock) _public(r),
        ],
        'nextCursor': null,
        'serverTime': '$_clock',
      });
    }
    final stored = store[id];
    if (request.method == 'DELETE') {
      if (stored != null && stored['deletedAt'] == null) {
        stored['deletedAt'] = '2026-10-12T00:00:00.000Z';
        stored['_serverUpdatedAt'] = ++_clock;
      }
      return http.Response('', 204);
    }
    final body = jsonDecode(request.body) as Map<String, Object?>;
    if (stored != null &&
        (stored['deletedAt'] != null ||
            (body['updatedAt']! as String).compareTo(
                  stored['updatedAt']! as String,
                ) <
                0)) {
      return _json(200, _public(stored));
    }
    store[id] = {
      ...body,
      'id': id,
      'deletedAt': null,
      '_serverUpdatedAt': ++_clock,
    };
    return _json(200, _public(store[id]!));
  }

  static Map<String, Object?> _public(Map<String, Object?> r) => {
    for (final e in r.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };

  Map<String, Object?> _summary(Map<String, Object?> a) => {
    for (final e in a.entries)
      if (e.key != 'segments' && !e.key.startsWith('_')) e.key: e.value,
    'photoCount': _photoCount(a['id']! as String),
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
