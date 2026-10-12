import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_type.dart';
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
  );

  static RemotePhoto photoFromJson(Json json) => RemotePhoto(
    id: json['id']! as String,
    url: Uri.parse(json['url']! as String),
    takenAt: parseTime(json['takenAt']),
  );

  static Activity activityFromJson(Json json) => Activity(
    id: json['id']! as String,
    type: ActivityType.values.byName(json['type']! as String),
    title: json['title']! as String,
    startedAt: parseTime(json['startedAt']),
    endedAt: parseTime(json['endedAt']),
    movingTime: Duration(milliseconds: (json['movingTimeMs']! as num).toInt()),
    shoeId: json['shoeId'] as String?,
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
