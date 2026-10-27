import '../entities/geo_point.dart';

/// A drawn shape matched to the walkable ways nearest to it.
class SnappedPath {
  const SnappedPath(this.points, this.distanceMeters);

  final List<GeoPoint> points;
  final double distanceMeters;
}

enum RouteSnapError {
  /// Snapping runs on the server, which needs an account.
  signedOut,

  /// No internet, or the routing engine failed; try again later.
  unavailable,

  /// The server has no routing engine set up.
  notConfigured,

  /// No walkable ways near the shape (drawn over water, say).
  noRoute,

  /// Longer than the server matches (100 km).
  tooLong,
}

class RouteSnapException implements Exception {
  const RouteSnapException(this.error);

  final RouteSnapError error;

  @override
  String toString() => 'RouteSnapException($error)';
}

/// Matches a shape to roads and footpaths (`POST /routes/snap`).
abstract interface class RouteSnapper {
  /// Throws [RouteSnapException].
  Future<SnappedPath> snap(List<GeoPoint> shape);
}
