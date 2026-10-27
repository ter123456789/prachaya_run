import '../../domain/entities/geo_point.dart';

/// Encoded Polyline Algorithm (Google), precision 5, latitude first: how
/// docs/api.md v1.4 sends coordinate lists.
abstract final class PolylineCodec {
  static const _factor = 1e5;

  static String encode(List<GeoPoint> points) {
    final out = StringBuffer();
    var prevLat = 0;
    var prevLng = 0;
    for (final p in points) {
      final lat = (p.latitude * _factor).round();
      final lng = (p.longitude * _factor).round();
      _encodeValue(lat - prevLat, out);
      _encodeValue(lng - prevLng, out);
      prevLat = lat;
      prevLng = lng;
    }
    return out.toString();
  }

  static void _encodeValue(int value, StringBuffer out) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  /// Throws [FormatException] for a malformed string.
  static List<GeoPoint> decode(String encoded) {
    final points = <GeoPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    int next() {
      var result = 0;
      var shift = 0;
      while (true) {
        if (index >= encoded.length) {
          throw FormatException('Truncated polyline', encoded, index);
        }
        final b = encoded.codeUnitAt(index++) - 63;
        if (b < 0 || b > 63) {
          throw FormatException('Bad polyline character', encoded, index - 1);
        }
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      lat += next();
      lng += next();
      points.add(GeoPoint(lat / _factor, lng / _factor));
    }
    return points;
  }
}
