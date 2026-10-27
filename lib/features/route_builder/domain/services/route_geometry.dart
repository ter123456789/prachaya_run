import 'dart:math' as math;

import '../entities/geo_point.dart';

const double _earthRadiusMeters = 6371000;

double _rad(double degrees) => degrees * math.pi / 180;

/// Great-circle distance (haversine).
double distanceMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

double pathLength(List<GeoPoint> points) {
  var sum = 0.0;
  for (var i = 1; i < points.length; i++) {
    sum += distanceMeters(points[i - 1], points[i]);
  }
  return sum;
}

/// Diagonal of the bounding box: the size of a shape, in metres.
double diagonalMeters(List<GeoPoint> points) {
  if (points.length < 2) return 0;
  var minLat = points.first.latitude, maxLat = minLat;
  var minLng = points.first.longitude, maxLng = minLng;
  for (final p in points) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return distanceMeters(GeoPoint(minLat, minLng), GeoPoint(maxLat, maxLng));
}

/// A point on a flat plane, in metres.
class PlanePoint {
  const PlanePoint(this.x, this.y);

  final double x;
  final double y;
}

/// Equirectangular projection to metres around [origin]; accurate to well
/// under 1 % across a city, which is all a running route spans.
class LocalPlane {
  LocalPlane(GeoPoint origin)
    : _lat0 = origin.latitude,
      _lng0 = origin.longitude,
      _xScale = math.cos(_rad(origin.latitude)) * _metersPerDegree;

  static const _metersPerDegree = _earthRadiusMeters * math.pi / 180;

  final double _lat0;
  final double _lng0;
  final double _xScale;

  PlanePoint project(GeoPoint p) => PlanePoint(
    (p.longitude - _lng0) * _xScale,
    (p.latitude - _lat0) * _metersPerDegree,
  );

  List<PlanePoint> projectAll(List<GeoPoint> points) => [
    for (final p in points) project(p),
  ];
}

/// Distance from [p] to the segment [a]–[b].
double distanceToSegment(PlanePoint p, PlanePoint a, PlanePoint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lengthSq = dx * dx + dy * dy;
  var t = lengthSq == 0
      ? 0.0
      : ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq;
  t = t.clamp(0.0, 1.0);
  final ex = a.x + t * dx - p.x;
  final ey = a.y + t * dy - p.y;
  return math.sqrt(ex * ex + ey * ey);
}

/// Distance from [p] to the nearest point of the polyline [line].
double distanceToLine(PlanePoint p, List<PlanePoint> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) return distanceToSegment(p, line.first, line.first);
  var best = double.infinity;
  for (var i = 1; i < line.length; i++) {
    best = math.min(best, distanceToSegment(p, line[i - 1], line[i]));
  }
  return best;
}

/// Ramer–Douglas–Peucker: drops points that lie within [toleranceMeters] of
/// the line through their neighbours. Keeps the first and last points.
List<GeoPoint> simplify(List<GeoPoint> points, double toleranceMeters) {
  if (points.length < 3) return List.of(points);
  final xy = LocalPlane(points.first).projectAll(points);
  final keep = List.filled(points.length, false)
    ..[0] = true
    ..[points.length - 1] = true;
  final stack = [(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    var farthest = -1;
    var farthestDistance = toleranceMeters;
    for (var i = start + 1; i < end; i++) {
      final d = distanceToSegment(xy[i], xy[start], xy[end]);
      if (d > farthestDistance) {
        farthest = i;
        farthestDistance = d;
      }
    }
    if (farthest < 0) continue;
    keep[farthest] = true;
    stack
      ..add((start, farthest))
      ..add((farthest, end));
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

/// Adds points along each segment so none is longer than [spacingMeters].
/// Every original point stays, so corners stay sharp.
List<GeoPoint> densify(List<GeoPoint> points, double spacingMeters) {
  if (points.length < 2) return List.of(points);
  final out = <GeoPoint>[points.first];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final steps = (distanceMeters(a, b) / spacingMeters).ceil();
    for (var s = 1; s < steps; s++) {
      final t = s / steps;
      out.add(
        GeoPoint(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ),
      );
    }
    out.add(b);
  }
  return out;
}
