/// A single GPS fix recorded during an activity.
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitudeMeters,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitudeMeters;
  final double? accuracyMeters;

  @override
  bool operator ==(Object other) =>
      other is TrackPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timestamp == timestamp &&
      other.altitudeMeters == altitudeMeters &&
      other.accuracyMeters == accuracyMeters;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    timestamp,
    altitudeMeters,
    accuracyMeters,
  );
}
