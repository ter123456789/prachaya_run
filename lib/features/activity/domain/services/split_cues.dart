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
  int _announced = 0;
  Duration _lastAt = Duration.zero;

  /// The cue when [meters] has passed a new whole unit, else null. When a
  /// jump crosses several units (GPS gap) only the latest is announced, with
  /// the time spread evenly.
  SplitCue? update(double meters, Duration movingTime) {
    final reached = (meters / unitMeters).floor();
    if (reached <= _announced) return null;
    final units = reached - _announced;
    final split = (movingTime - _lastAt) ~/ units;
    _announced = reached;
    _lastAt = movingTime;
    return SplitCue(
      index: reached,
      splitTime: split,
      totalTime: movingTime,
      unitMeters: unitMeters,
    );
  }
}
