import '../entities/heart_rate.dart';

class HeartRateSummary {
  const HeartRateSummary({
    required this.averageBpm,
    required this.maxBpm,
    required this.zoneTimes,
    required this.sparse,
  });

  final int averageBpm;
  final int maxBpm;

  /// Time in zones 1–5 (index 0 = zone 1); empty when no zones were given.
  /// Time below zone 1 is not counted.
  final List<Duration> zoneTimes;

  /// Samples too far apart (e.g. imported from a watch that was not in a
  /// workout) for zone times to mean much.
  final bool sparse;
}

/// Each sample stands for the time until the next one, but never more than
/// [maxGap], so a sensor that dropped out (or a pause, whose samples are not
/// kept) does not stretch the reading before it. The last sample counts for
/// one second.
///
/// [zoneLowBpm] holds each zone's first bpm, lowest zone first. Null when
/// [samples] is empty.
HeartRateSummary? summarizeHeartRate(
  List<HeartRateSample> samples, {
  List<int>? zoneLowBpm,
  Duration maxGap = const Duration(seconds: 5),
}) {
  if (samples.isEmpty) return null;
  final zones = zoneLowBpm ?? const <int>[];
  final zoneMs = List<int>.filled(zones.length, 0);
  var weighted = 0.0;
  var totalMs = 0;
  var max = 0;
  var spanMs = 0;
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i];
    final gap = i + 1 < samples.length
        ? samples[i + 1].timestamp.difference(s.timestamp).inMilliseconds
        : 1000;
    if (i + 1 < samples.length) spanMs += gap;
    final ms = gap.clamp(0, maxGap.inMilliseconds);
    weighted += s.bpm * ms;
    totalMs += ms;
    if (s.bpm > max) max = s.bpm;
    for (var z = zones.length - 1; z >= 0; z--) {
      if (s.bpm >= zones[z]) {
        zoneMs[z] += ms;
        break;
      }
    }
  }
  final average = totalMs == 0
      ? samples.map((s) => s.bpm).reduce((a, b) => a + b) / samples.length
      : weighted / totalMs;
  final meanGapMs = samples.length < 2 ? 0 : spanMs / (samples.length - 1);
  return HeartRateSummary(
    averageBpm: average.round(),
    maxBpm: max,
    zoneTimes: [for (final ms in zoneMs) Duration(milliseconds: ms)],
    sparse: meanGapMs > 30000,
  );
}
