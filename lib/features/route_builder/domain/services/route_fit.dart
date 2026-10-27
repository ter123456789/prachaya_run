import 'dart:math' as math;

import '../entities/geo_point.dart';
import 'route_geometry.dart';

/// How closely a snapped route follows the drawing.
class RouteFit {
  const RouteFit({required this.score, this.offShape = const []});

  /// 0–100: the smaller of the share of the route that runs along the
  /// drawing and the share of the drawing the route covers.
  final int score;

  /// Point-index ranges `(start, end)` of the route that stray from the
  /// drawing (detours around blocks, rivers, ...).
  final List<(int, int)> offShape;
}

/// How far the route may stray and still count as following the drawing:
/// 6 % of the shape's size, between 30 and 120 m.
double fitTolerance(List<GeoPoint> drawn) =>
    (diagonalMeters(drawn) * 0.06).clamp(30.0, 120.0);

RouteFit fitRoute(List<GeoPoint> drawn, List<GeoPoint> route) {
  if (drawn.length < 2 || route.length < 2) return const RouteFit(score: 0);
  final tolerance = fitTolerance(drawn);
  final plane = LocalPlane(drawn.first);
  final drawnXy = plane.projectAll(drawn);
  final routeXy = plane.projectAll(route);

  // Route → drawing: each route segment counts by its midpoint.
  var total = 0.0;
  var along = 0.0;
  final offShape = <(int, int)>[];
  int? runStart;
  var runLength = 0.0;
  void closeRun(int end) {
    if (runStart != null && runLength >= tolerance) {
      offShape.add((runStart!, end));
    }
    runStart = null;
    runLength = 0;
  }

  for (var i = 1; i < routeXy.length; i++) {
    final a = routeXy[i - 1];
    final b = routeXy[i];
    final length = math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2));
    final mid = PlanePoint((a.x + b.x) / 2, (a.y + b.y) / 2);
    total += length;
    if (distanceToLine(mid, drawnXy) <= tolerance) {
      along += length;
      closeRun(i - 1);
    } else {
      runStart ??= i - 1;
      runLength += length;
    }
  }
  closeRun(routeXy.length - 1);

  // Drawing → route: sample the drawing every third of the tolerance.
  final samples = plane.projectAll(densify(drawn, tolerance / 3));
  final covered = samples
      .where((p) => distanceToLine(p, routeXy) <= tolerance)
      .length;

  final alongShare = total == 0 ? 0.0 : along / total;
  final coverShare = covered / samples.length;
  return RouteFit(
    score: (100 * math.min(alongShare, coverShare)).round(),
    offShape: offShape,
  );
}
