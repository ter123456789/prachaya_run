import 'dart:math' as math;

import '../entities/geo_point.dart';
import '../entities/planned_route.dart';
import '../repositories/route_snapper.dart';
import '../services/route_fit.dart';
import '../services/route_geometry.dart';

/// The server's limits for `POST /routes/snap` (docs/api.md v1.4).
const double kMaxShapeMeters = 100000;
const int kMaxShapePoints = 2000;

/// A drawing turned into something to run.
class RoutePlan {
  const RoutePlan({
    required this.drawn,
    this.route,
    required this.distanceMeters,
    this.fit,
  });

  /// The drawing alone, when it cannot be snapped (signed out, offline).
  factory RoutePlan.unsnapped(List<GeoPoint> drawn) =>
      RoutePlan(drawn: drawn, distanceMeters: pathLength(drawn));

  final List<GeoPoint> drawn;
  final List<GeoPoint>? route;
  final double distanceMeters;
  final RouteFit? fit;
}

/// Finger strokes → one clean shape: strokes joined in drawing order, hand
/// jitter removed (RDP at 1 % of the shape's size, 3–15 m), and the start
/// repeated at the end when [closed].
List<GeoPoint> drawnShape(
  List<List<GeoPoint>> strokes, {
  required bool closed,
}) {
  final joined = [for (final s in strokes) ...s];
  if (joined.length < 2) return joined;
  final jitter = (diagonalMeters(joined) * 0.01).clamp(3.0, 15.0);
  final shape = simplify(joined, jitter);
  if (closed && shape.length > 2 && shape.last != shape.first) {
    shape.add(shape.first);
  }
  return shape;
}

/// Matches a drawing to walkable ways and scores how well the result
/// follows it.
class SnapDrawing {
  const SnapDrawing(this._snapper);

  final RouteSnapper _snapper;

  /// Throws [RouteValidationException] for fewer than two points, and
  /// [RouteSnapException].
  Future<RoutePlan> call(
    List<List<GeoPoint>> strokes, {
    required bool closed,
  }) async {
    final drawn = drawnShape(strokes, closed: closed);
    if (drawn.length < 2 || pathLength(drawn) < 1) {
      throw const RouteValidationException();
    }
    final length = pathLength(drawn);
    if (length > kMaxShapeMeters) {
      throw const RouteSnapException(RouteSnapError.tooLong);
    }
    // Even points every 35 m or more give the matcher something to hold on
    // to along long straight lines, within the server's point limit.
    final spacing = math.max(35.0, length / (kMaxShapePoints - 200));
    final snapped = await _snapper.snap(densify(drawn, spacing));
    // Collinear points add bytes, not shape.
    final route = simplify(snapped.points, 1.5);
    return RoutePlan(
      drawn: drawn,
      route: route,
      distanceMeters: snapped.distanceMeters,
      fit: fitRoute(drawn, route),
    );
  }
}
