import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/track_point.dart';
import 'remote_activity_summary.dart';

typedef Row = Map<String, Object?>;

/// Converts between domain entities and SQLite rows.
abstract final class ActivityRowMapper {
  /// A row for an activity recorded on this device, waiting to be synced.
  static Row activityToRow(
    Activity a, {
    required DateTime updatedAt,
    required String? ownerId,
  }) => {
    'id': a.id,
    'type': a.type.name,
    'title': a.title,
    'started_at': a.startedAt.millisecondsSinceEpoch,
    'ended_at': a.endedAt.millisecondsSinceEpoch,
    'moving_time_ms': a.movingTime.inMilliseconds,
    'distance_m': a.distanceMeters,
    'elevation_gain_m': a.elevationGainMeters,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'synced': 0,
    'has_track': 1,
    'owner_id': ownerId,
  };

  /// A row matching the server's copy. [hasTrack] says whether the GPS
  /// track is stored locally too.
  static Row remoteSummaryToRow(
    RemoteActivitySummary s, {
    required bool hasTrack,
    required String ownerId,
  }) => {
    'id': s.id,
    'type': s.type.name,
    'title': s.title,
    'started_at': s.startedAt.millisecondsSinceEpoch,
    'ended_at': s.endedAt.millisecondsSinceEpoch,
    'moving_time_ms': s.movingTime.inMilliseconds,
    'distance_m': s.distanceMeters,
    'elevation_gain_m': s.elevationGainMeters,
    'updated_at': s.updatedAt.millisecondsSinceEpoch,
    'deleted_at': null,
    'synced': 1,
    'has_track': hasTrack ? 1 : 0,
    'owner_id': ownerId,
  };

  static Iterable<Row> pointsToRows(Activity a) sync* {
    for (var s = 0; s < a.segments.length; s++) {
      final segment = a.segments[s];
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        yield {
          'activity_id': a.id,
          'segment': s,
          'seq': i,
          'lat': point.latitude,
          'lng': point.longitude,
          'altitude': point.altitudeMeters,
          'accuracy': point.accuracyMeters,
          'timestamp': point.timestamp.millisecondsSinceEpoch,
        };
      }
    }
  }

  static ActivitySummary summaryFromRow(Row row) => ActivitySummary(
    id: row['id']! as String,
    type: ActivityType.values.byName(row['type']! as String),
    title: row['title']! as String,
    startedAt: _time(row['started_at']),
    movingTime: Duration(milliseconds: row['moving_time_ms']! as int),
    distanceMeters: (row['distance_m']! as num).toDouble(),
    elevationGainMeters: (row['elevation_gain_m']! as num).toDouble(),
  );

  /// [pointRows] must be ordered by segment, then seq.
  static Activity activityFromRows(Row row, List<Row> pointRows) {
    final segments = <List<TrackPoint>>[];
    int? currentSegment;
    for (final r in pointRows) {
      final segment = r['segment']! as int;
      if (segment != currentSegment) {
        segments.add([]);
        currentSegment = segment;
      }
      segments.last.add(
        TrackPoint(
          latitude: (r['lat']! as num).toDouble(),
          longitude: (r['lng']! as num).toDouble(),
          altitudeMeters: (r['altitude'] as num?)?.toDouble(),
          accuracyMeters: (r['accuracy'] as num?)?.toDouble(),
          timestamp: _time(r['timestamp']),
        ),
      );
    }
    return Activity(
      id: row['id']! as String,
      type: ActivityType.values.byName(row['type']! as String),
      title: row['title']! as String,
      startedAt: _time(row['started_at']),
      endedAt: _time(row['ended_at']),
      movingTime: Duration(milliseconds: row['moving_time_ms']! as int),
      segments: segments,
    );
  }

  static DateTime _time(Object? millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis! as int);
}
