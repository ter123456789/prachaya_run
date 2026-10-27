import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_origin.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/heart_rate.dart';
import '../../domain/entities/track_point.dart';
import 'remote_activity_summary.dart';

typedef Json = Map<String, Object?>;

/// Converts between domain entities and the API's JSON (docs/api.md).
abstract final class ActivityJsonMapper {
  static Json activityToJson(Activity a, {required DateTime updatedAt}) => {
    'id': a.id,
    'type': a.type.name,
    'title': a.title,
    'startedAt': time(a.startedAt),
    'endedAt': time(a.endedAt),
    'movingTimeMs': a.movingTime.inMilliseconds,
    'updatedAt': time(updatedAt),
    'shoeId': a.shoeId,
    'heartRate': heartRateToJson(a),
    'origin': originToJson(a.origin),
    // v1.6: without points the server takes the watch's figures.
    if (!a.hasTrack) ...{
      'distanceM': a.distanceMeters,
      'elevationGainM': a.elevationGainMeters,
    },
    'segments': [
      for (final segment in a.segments)
        [
          for (final p in segment)
            {
              'lat': p.latitude,
              'lng': p.longitude,
              'altitude': p.altitudeMeters,
              'accuracy': p.accuracyMeters,
              'timestamp': time(p.timestamp),
            },
        ],
    ],
  };

  /// api.md v1.5: samples with `t` in ms since `startedAt`.
  static Json? heartRateToJson(Activity a) {
    final hr = a.heartRate;
    if (hr == null) return null;
    final start = a.startedAt.millisecondsSinceEpoch;
    return {
      'source': hr.source.name,
      'samples': [
        for (final s in hr.samples)
          {'t': s.timestamp.millisecondsSinceEpoch - start, 'bpm': s.bpm},
      ],
    };
  }

  static HeartRateTrack? heartRateFromJson(Object? value, DateTime start) {
    if (value == null) return null;
    final json = value as Json;
    final source = HeartRateSource.values.asNameMap()[json['source']];
    // A source added by a newer server: keep the samples as Bluetooth ones.
    final base = start.millisecondsSinceEpoch;
    return HeartRateTrack(
      source: source ?? HeartRateSource.ble,
      samples: [
        for (final s in (json['samples']! as List<Object?>).cast<Json>())
          HeartRateSample(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              base + (s['t']! as num).toInt(),
            ),
            bpm: (s['bpm']! as num).toInt(),
          ),
      ],
    );
  }

  static Json? originToJson(ActivityOrigin o) => o.isPhone
      ? null
      : {'kind': o.kind.name, 'app': o.app, 'device': o.device};

  static ActivityOrigin originFromJson(Object? value) {
    if (value == null) return ActivityOrigin.phone;
    final json = value as Json;
    final kind = OriginKind.values.asNameMap()[json['kind']];
    return ActivityOrigin(
      // A kind added by a newer server still reads as "from a watch".
      kind ?? OriginKind.health,
      app: json['app'] as String?,
      device: json['device'] as String?,
    );
  }

  static RemoteActivitySummary summaryFromJson(
    Json json,
  ) => RemoteActivitySummary(
    id: json['id']! as String,
    type: ActivityType.values.byName(json['type']! as String),
    title: json['title']! as String,
    startedAt: parseTime(json['startedAt']),
    endedAt: parseTime(json['endedAt']),
    movingTime: Duration(milliseconds: (json['movingTimeMs']! as num).toInt()),
    updatedAt: parseTime(json['updatedAt']),
    distanceMeters: (json['distanceM']! as num).toDouble(),
    elevationGainMeters: (json['elevationGainM']! as num).toDouble(),
    deletedAt: json['deletedAt'] == null ? null : parseTime(json['deletedAt']),
    photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
    shoeId: json['shoeId'] as String?,
    origin: originFromJson(json['origin']),
  );

  static RemotePhoto photoFromJson(Json json) => RemotePhoto(
    id: json['id']! as String,
    url: Uri.parse(json['url']! as String),
    takenAt: parseTime(json['takenAt']),
  );

  static Activity activityFromJson(Json json) {
    final startedAt = parseTime(json['startedAt']);
    return Activity(
      id: json['id']! as String,
      type: ActivityType.values.byName(json['type']! as String),
      title: json['title']! as String,
      startedAt: startedAt,
      endedAt: parseTime(json['endedAt']),
      movingTime: Duration(
        milliseconds: (json['movingTimeMs']! as num).toInt(),
      ),
      shoeId: json['shoeId'] as String?,
      heartRate: heartRateFromJson(json['heartRate'], startedAt),
      origin: originFromJson(json['origin']),
      reportedDistanceMeters: (json['distanceM'] as num?)?.toDouble(),
      reportedElevationGainMeters: (json['elevationGainM'] as num?)?.toDouble(),
      segments: [
        for (final segment in json['segments']! as List<Object?>)
          [
            for (final p in (segment! as List<Object?>).cast<Json>())
              TrackPoint(
                latitude: (p['lat']! as num).toDouble(),
                longitude: (p['lng']! as num).toDouble(),
                altitudeMeters: (p['altitude'] as num?)?.toDouble(),
                accuracyMeters: (p['accuracy'] as num?)?.toDouble(),
                timestamp: parseTime(p['timestamp']),
              ),
          ],
      ],
    );
  }

  static RemoteChangesPage changesPageFromJson(Json json) => RemoteChangesPage(
    items: [
      for (final item in (json['items']! as List<Object?>).cast<Json>())
        summaryFromJson(item),
    ],
    nextCursor: json['nextCursor'] as String?,
    serverTime: json['serverTime']! as String,
  );

  /// ISO 8601 UTC with exactly milliseconds, e.g. `2026-10-11T06:00:00.000Z`.
  static String time(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();

  /// Parsed to local time, like the timestamps read from SQLite.
  static DateTime parseTime(Object? value) =>
      DateTime.parse(value! as String).toLocal();
}
