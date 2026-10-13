import '../entities/activity.dart';
import '../entities/activity_type.dart';
import 'geo_math.dart';

/// Fastest time over [meters] anywhere inside [activity]'s track, timed by
/// GPS timestamps with pauses excluded (gaps between segments don't count).
/// Null when the track is shorter than [meters].
Duration? bestEffort(Activity activity, double meters) {
  // Cumulative moving distance and time at every point.
  final distance = <double>[];
  final time = <int>[]; // ms
  var d = 0.0;
  var t = 0;
  for (final segment in activity.segments) {
    for (var i = 0; i < segment.length; i++) {
      if (i > 0) {
        d += distanceBetween(segment[i - 1], segment[i]);
        t += segment[i].timestamp
            .difference(segment[i - 1].timestamp)
            .inMilliseconds;
      }
      distance.add(d);
      time.add(t);
    }
  }
  if (distance.isEmpty || distance.last < meters) return null;

  int? best;
  var end = 0;
  for (var start = 0; start < distance.length; start++) {
    final target = distance[start] + meters;
    while (end < distance.length && distance[end] < target) {
      end++;
    }
    if (end >= distance.length) break;
    // Interpolate inside the step that crosses the target distance.
    final step = distance[end] - distance[end - 1];
    final share = step <= 0 ? 1.0 : (target - distance[end - 1]) / step;
    final finish = time[end - 1] + (time[end] - time[end - 1]) * share;
    final effort = (finish - time[start]).round();
    if (best == null || effort < best) best = effort;
  }
  return best == null ? null : Duration(milliseconds: best);
}

/// Personal bests over the standard distances, from runs only.
class PersonalBests {
  const PersonalBests({this.fiveK, this.tenK});

  /// Fastest 5 km and 10 km inside any run; null when no run is that long.
  factory PersonalBests.from(Iterable<Activity> activities) {
    Duration? five;
    Duration? ten;
    Duration? faster(Duration? a, Duration? b) =>
        a == null ? b : (b == null || a <= b ? a : b);
    for (final a in activities) {
      if (a.type != ActivityType.run) continue;
      five = faster(five, bestEffort(a, 5000));
      ten = faster(ten, bestEffort(a, 10000));
    }
    return PersonalBests(fiveK: five, tenK: ten);
  }

  final Duration? fiveK;
  final Duration? tenK;

  bool get isEmpty => fiveK == null && tenK == null;

  @override
  bool operator ==(Object other) =>
      other is PersonalBests && other.fiveK == fiveK && other.tenK == tenK;

  @override
  int get hashCode => Object.hash(fiveK, tenK);
}
