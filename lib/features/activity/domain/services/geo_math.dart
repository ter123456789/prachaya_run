import 'dart:math' as math;

import '../entities/track_point.dart';

const double _earthRadiusMeters = 6371000;

/// Great-circle distance between two points (haversine).
double distanceBetween(TrackPoint a, TrackPoint b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLat = lat2 - lat1;
  final dLng = _toRadians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Accumulates climbing while ignoring GPS altitude noise below [threshold].
class ElevationGainCounter {
  ElevationGainCounter({this.threshold = 3});

  final double threshold;
  double _gain = 0;
  double? _reference;

  double get gain => _gain;

  void add(double? altitude) {
    if (altitude == null) return;
    final reference = _reference;
    if (reference == null) {
      _reference = altitude;
      return;
    }
    final delta = altitude - reference;
    if (delta >= threshold) {
      _gain += delta;
      _reference = altitude;
    } else if (delta <= -threshold) {
      _reference = altitude;
    }
  }

  /// Call between segments so the gap across a pause is not counted.
  void breakSegment() => _reference = null;
}
