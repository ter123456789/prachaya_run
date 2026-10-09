import 'dart:math' as math;

import 'track_point.dart';

class ShapePoint {
  const ShapePoint(this.x, this.y);

  final double x;
  final double y;
}

/// A GPS track projected to a flat shape that fits inside a 1×1 box,
/// north up, centred, with its true proportions kept. Ready to scale onto
/// any canvas without needing map tiles.
class RouteShape {
  const RouteShape._(this.segments, this.aspectRatio);

  factory RouteShape.fromSegments(List<List<TrackPoint>> segments) {
    final points = segments.expand((s) => s).toList();
    if (points.length < 2) return const RouteShape._([], 1);

    // Equirectangular projection; good enough at activity scale.
    final meanLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final xScale = math.cos(meanLat * math.pi / 180);
    double px(TrackPoint p) => p.longitude * xScale;
    double py(TrackPoint p) => -p.latitude; // screen y grows downward

    final minX = points.map(px).reduce(math.min);
    final maxX = points.map(px).reduce(math.max);
    final minY = points.map(py).reduce(math.min);
    final maxY = points.map(py).reduce(math.max);
    final width = maxX - minX;
    final height = maxY - minY;
    final extent = math.max(width, height);
    if (extent == 0) return const RouteShape._([], 1);

    final offsetX = (1 - width / extent) / 2;
    final offsetY = (1 - height / extent) / 2;
    final normalized = [
      for (final segment in segments)
        if (segment.length > 1)
          [
            for (final p in segment)
              ShapePoint(
                offsetX + (px(p) - minX) / extent,
                offsetY + (py(p) - minY) / extent,
              ),
          ],
    ];
    return RouteShape._(
      normalized,
      height == 0 ? double.infinity : width / height,
    );
  }

  /// Polylines with coordinates in [0, 1].
  final List<List<ShapePoint>> segments;

  /// Width / height of the route's bounding box.
  final double aspectRatio;

  bool get isEmpty => segments.isEmpty;
}
