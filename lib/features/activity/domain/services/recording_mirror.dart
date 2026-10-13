/// What the lock screen / Dynamic Island shows about the recording under
/// way. Texts are already formatted in the app's unit.
class LiveSnapshot {
  const LiveSnapshot({
    required this.title,
    required this.paused,
    required this.elapsed,
    required this.distance,
    required this.distanceUnit,
    required this.paceLabel,
    required this.pace,
    required this.paceUnit,
    required this.lapNumber,
    required this.lapDistance,
    required this.calories,
    required this.elevation,
  });

  /// `กำลังบันทึกวิ่ง`
  final String title;
  final bool paused;

  /// Moving time; the live clock counts on from it while not [paused].
  final Duration elapsed;
  final String distance;
  final String distanceUnit;

  /// `เพซเฉลี่ย` / `ความเร็วเฉลี่ย`
  final String paceLabel;
  final String pace;
  final String paceUnit;
  final int lapNumber;

  /// The lap under way, with its unit: `0.83 กม.`
  final String lapDistance;
  final String calories;
  final String elevation;

  @override
  bool operator ==(Object other) =>
      other is LiveSnapshot &&
      other.title == title &&
      other.paused == paused &&
      other.elapsed == elapsed &&
      other.distance == distance &&
      other.pace == pace &&
      other.paceUnit == paceUnit &&
      other.lapNumber == lapNumber &&
      other.lapDistance == lapDistance &&
      other.calories == calories &&
      other.elevation == elevation;

  @override
  int get hashCode => Object.hash(
    title,
    paused,
    elapsed,
    distance,
    pace,
    paceUnit,
    lapNumber,
    lapDistance,
    calories,
    elevation,
  );
}

/// Buttons on the Live Activity / ongoing notification.
enum LiveCommand { pause, resume, lap }

/// The recording shown outside the app: iOS Live Activity (lock screen and
/// Dynamic Island), Android ongoing notification.
abstract interface class RecordingMirror {
  /// Starts or updates it.
  Future<void> show(LiveSnapshot snapshot);

  /// Removes it (finished, saved or discarded).
  Future<void> end();

  Stream<LiveCommand> get commands;
}
