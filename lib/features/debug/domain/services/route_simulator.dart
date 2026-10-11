import 'dart:math' as math;

import '../../../activity/domain/entities/track_point.dart';
import '../entities/gps_simulation.dart';

class _Waypoint {
  const _Waypoint(this.lat, this.lng, this.alt);

  final double lat;
  final double lng;
  final double alt;
}

const _routes = <SimRoute, (List<_Waypoint>, bool)>{
  SimRoute.lumpini: (
    [
      _Waypoint(13.7316, 100.5390, 5),
      _Waypoint(13.7316, 100.5446, 5),
      _Waypoint(13.7262, 100.5446, 6),
      _Waypoint(13.7262, 100.5390, 5),
    ],
    true,
  ),
  SimRoute.riverside: (
    [
      _Waypoint(13.7400, 100.4950, 2),
      _Waypoint(13.7460, 100.4920, 2),
      _Waypoint(13.7530, 100.4925, 3),
      _Waypoint(13.7600, 100.4960, 2),
    ],
    false,
  ),
  SimRoute.doiSuthep: (
    [
      _Waypoint(18.8035, 98.9535, 340),
      _Waypoint(18.8070, 98.9400, 520),
      _Waypoint(18.8090, 98.9300, 750),
      _Waypoint(18.8050, 98.9216, 1000),
    ],
    false,
  ),
};

/// Walks a [SimRoute] and produces GPS fixes. Loops repeat; open routes go
/// out and back. Pure Dart so it is shared by the fake GPS and the
/// sample-data generator, and testable.
class RouteSimulator {
  RouteSimulator(this.route, {this.noise = true, math.Random? random})
    : _random = random ?? math.Random(),
      _points = _routes[route]!.$1,
      _loop = _routes[route]!.$2 {
    final legs = _loop ? _points.length : _points.length - 1;
    var total = 0.0;
    for (var i = 0; i < legs; i++) {
      _cumulative.add(total);
      total += _metersBetween(_points[i], _points[(i + 1) % _points.length]);
    }
    _length = total;
  }

  final SimRoute route;
  final bool noise;
  final math.Random _random;
  final List<_Waypoint> _points;
  final bool _loop;
  final List<double> _cumulative = [];
  late final double _length;

  /// Length of one lap (loop) or one way (out-and-back), in meters.
  double get lapMeters => _length;

  /// The fix after covering [meters] since the start, at time [at].
  TrackPoint pointAt(double meters, DateTime at) {
    var d = meters % (_loop ? _length : 2 * _length);
    if (!_loop && d > _length) d = 2 * _length - d; // heading back
    var leg = _cumulative.length - 1;
    while (leg > 0 && _cumulative[leg] > d) {
      leg--;
    }
    final a = _points[leg];
    final b = _points[(leg + 1) % _points.length];
    final legLength = _metersBetween(a, b);
    final t = legLength == 0 ? 0.0 : (d - _cumulative[leg]) / legLength;

    var lat = a.lat + (b.lat - a.lat) * t;
    var lng = a.lng + (b.lng - a.lng) * t;
    var alt = a.alt + (b.alt - a.alt) * t;
    double? accuracy = 5;
    if (noise) {
      // Gentle rolling terrain, ±3 m jitter, and 2 % bad fixes the
      // recorder should drop (accuracy > 30 m).
      alt += 4 * math.sin(2 * math.pi * meters / 800);
      lat += _jitter(3) / 111320;
      lng += _jitter(3) / (111320 * math.cos(lat * math.pi / 180));
      accuracy = _random.nextDouble() < 0.02
          ? 45
          : 4 + _random.nextDouble() * 8;
    }
    return TrackPoint(
      latitude: lat,
      longitude: lng,
      altitudeMeters: alt,
      accuracyMeters: accuracy,
      timestamp: at,
    );
  }

  double _jitter(double meters) => (_random.nextDouble() * 2 - 1) * meters;

  static double _metersBetween(_Waypoint a, _Waypoint b) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) *
            math.cos(rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
