import '../../domain/entities/activity_type.dart';

/// An activity as the server describes it, without the GPS track.
/// Distance and climb are computed by the server.
class RemoteActivitySummary {
  const RemoteActivitySummary({
    required this.id,
    required this.type,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.movingTime,
    required this.updatedAt,
    required this.distanceMeters,
    required this.elevationGainMeters,
    this.deletedAt,
    this.photoCount = 0,
  });

  final String id;
  final ActivityType type;
  final String title;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration movingTime;
  final DateTime updatedAt;
  final double distanceMeters;
  final double elevationGainMeters;
  final DateTime? deletedAt;
  final int photoCount;

  bool get isDeleted => deletedAt != null;
}

/// One page of `GET /activities?updatedSince=`.
class RemoteChangesPage {
  const RemoteChangesPage({
    required this.items,
    required this.nextCursor,
    required this.serverTime,
  });

  final List<RemoteActivitySummary> items;
  final String? nextCursor;

  /// Kept verbatim and sent back as the next `updatedSince`.
  final String serverTime;
}

/// A photo as the server lists it. [url] is signed and expires.
class RemotePhoto {
  const RemotePhoto({
    required this.id,
    required this.url,
    required this.takenAt,
  });

  final String id;
  final Uri url;
  final DateTime takenAt;
}
