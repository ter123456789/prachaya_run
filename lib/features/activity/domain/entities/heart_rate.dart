/// One heart-rate reading kept with an activity.
class HeartRateSample {
  const HeartRateSample({required this.timestamp, required this.bpm});

  final DateTime timestamp;
  final int bpm;

  @override
  bool operator ==(Object other) =>
      other is HeartRateSample &&
      other.timestamp == timestamp &&
      other.bpm == bpm;

  @override
  int get hashCode => Object.hash(timestamp, bpm);

  @override
  String toString() => 'HeartRateSample($bpm @ $timestamp)';
}

/// Where an activity's heart rate came from (api.md v1.5).
enum HeartRateSource {
  /// A Bluetooth sensor paired with the phone while recording.
  ble,

  /// Imported from Apple Health / Health Connect afterwards.
  health,

  /// Recorded by a watch app.
  watch,
}

/// An activity's heart rate: a series of its own, separate from the GPS
/// track (the two arrive at different rates). Samples taken while paused
/// are not kept.
class HeartRateTrack {
  HeartRateTrack({required this.source, required List<HeartRateSample> samples})
    : samples = List.unmodifiable(samples);

  final HeartRateSource source;

  /// Oldest first.
  final List<HeartRateSample> samples;

  @override
  bool operator ==(Object other) =>
      other is HeartRateTrack &&
      other.source == source &&
      _sameSamples(other.samples, samples);

  @override
  int get hashCode => Object.hash(source, Object.hashAll(samples));

  static bool _sameSamples(List<HeartRateSample> a, List<HeartRateSample> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
