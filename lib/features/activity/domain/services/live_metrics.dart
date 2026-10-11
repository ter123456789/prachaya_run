import '../entities/track_point.dart';
import 'geo_math.dart';

/// Speed over the last [window] of the current (last) segment, in m/s;
/// null until that segment spans at least [minSpan]. Smooths GPS jitter
/// for the "live pace" badge.
double? recentSpeedMps(
  List<List<TrackPoint>> segments, {
  Duration window = const Duration(seconds: 30),
  Duration minSpan = const Duration(seconds: 5),
}) {
  if (segments.isEmpty) return null;
  final segment = segments.last;
  if (segment.length < 2) return null;
  final end = segment.last.timestamp;
  var meters = 0.0;
  var i = segment.length - 1;
  while (i > 0 && end.difference(segment[i - 1].timestamp) <= window) {
    meters += distanceBetween(segment[i - 1], segment[i]);
    i--;
  }
  final span = end.difference(segment[i].timestamp);
  if (span < minSpan || span.inMilliseconds <= 0) return null;
  return meters / (span.inMilliseconds / 1000);
}
