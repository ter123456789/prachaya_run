/// One whole unit (km or mile) just completed while recording.
class SplitCue {
  const SplitCue({
    required this.index,
    required this.splitTime,
    required this.totalTime,
    required this.unitMeters,
  });

  /// 1 for the first km / mile.
  final int index;

  /// Time for this unit alone.
  final Duration splitTime;
  final Duration totalTime;
  final double unitMeters;

  /// Average speed over this unit, m/s.
  double get splitSpeedMps {
    final s = splitTime.inMilliseconds / 1000;
    return s <= 0 ? 0 : unitMeters / s;
  }
}

/// Announces each whole unit once, in order, as the distance grows.
class SplitCueTracker {
  SplitCueTracker(this.unitMeters);

  final double unitMeters;

  /// Moving time at each unit announced so far.
  final List<Duration> _at = [];

  /// The cue when [meters] has passed a new whole unit, else null. When a
  /// jump crosses several units (GPS gap) only the latest is announced, with
  /// the time spread evenly. When [meters] drops back (a vehicle stretch
  /// was taken out) the units it had passed are announced again later.
  SplitCue? update(double meters, Duration movingTime) {
    final reached = (meters / unitMeters).floor();
    if (reached < _at.length) _at.removeRange(reached, _at.length);
    if (reached <= _at.length) return null;
    final units = reached - _at.length;
    final last = _at.isEmpty ? Duration.zero : _at.last;
    final split = (movingTime - last) ~/ units;
    for (var k = 1; k <= units; k++) {
      _at.add(k == units ? movingTime : last + split * k);
    }
    return SplitCue(
      index: reached,
      splitTime: split,
      totalTime: movingTime,
      unitMeters: unitMeters,
    );
  }
}
