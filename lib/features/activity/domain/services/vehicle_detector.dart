import '../entities/activity_type.dart';
import '../entities/track_point.dart';
import 'geo_math.dart';

/// Speeds that tell a car, bus or train apart from the athlete moving on
/// their own.
class VehicleThresholds {
  const VehicleThresholds({
    required this.enterMps,
    required this.exitMps,
    this.window = const Duration(seconds: 20),
    this.minSpan = const Duration(seconds: 12),
    this.exitAfter = const Duration(seconds: 60),
    this.enterFixes = 3,
  });

  /// Runs and hikes: 25 km/h held for [window] is beyond anyone but elite
  /// sprinters. Rides: 72 km/h, above a fast descent.
  factory VehicleThresholds.forType(ActivityType type) => switch (type) {
    ActivityType.run ||
    ActivityType.hike => const VehicleThresholds(enterMps: 7, exitMps: 5.5),
    ActivityType.ride => const VehicleThresholds(enterMps: 20, exitMps: 14),
  };

  /// Speed over [window] at or above which the athlete is in a vehicle.
  final double enterMps;

  /// In a vehicle, speed must stay below this for [exitAfter] to count as
  /// back on foot (or on the bike).
  final double exitMps;

  final Duration window;

  /// The window must span at least this long before its speed is trusted.
  final Duration minSpan;
  final Duration exitAfter;

  /// Fixes in a row that must read fast, so one GPS jump is not a ride.
  final int enterFixes;
}

/// The athlete got into ([inVehicle]) or out of a vehicle at [since].
class VehicleChange {
  const VehicleChange({required this.inVehicle, required this.since});

  final bool inVehicle;
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is VehicleChange &&
      other.inVehicle == inVehicle &&
      other.since == since;

  @override
  int get hashCode => Object.hash(inVehicle, since);
}

/// Watches raw GPS fixes during a recording and reports when the speed
/// says the athlete is riding in a vehicle, so that stretch is not counted.
///
/// Speed is the straight-line displacement over the last
/// [VehicleThresholds.window], which GPS jitter barely moves (a summed
/// path would read a standing phone as jogging).
class VehicleDetector {
  VehicleDetector(this.thresholds, {this.maxAccuracyMeters = 30});

  final VehicleThresholds thresholds;

  /// Fixes less accurate than this are ignored.
  final double maxAccuracyMeters;

  final List<TrackPoint> _recent = [];
  bool _inVehicle = false;
  int _fastFixes = 0;
  DateTime? _slowSince;

  bool get inVehicle => _inVehicle;

  /// Returns the change [point] completes, if any.
  VehicleChange? add(TrackPoint point) {
    final accuracy = point.accuracyMeters;
    if (accuracy != null && accuracy > maxAccuracyMeters) return null;
    final now = point.timestamp;
    if (_recent.isNotEmpty && !now.isAfter(_recent.last.timestamp)) {
      return null;
    }
    _recent.add(point);
    final keep = now.subtract(thresholds.window + thresholds.exitAfter);
    _recent.removeWhere((p) => p.timestamp.isBefore(keep));

    final window = _window(now);
    if (window == null) return null;
    final (start, speed) = window;

    if (!_inVehicle) {
      _fastFixes = speed < thresholds.enterMps ? 0 : _fastFixes + 1;
      if (_fastFixes < thresholds.enterFixes) return null;
      _inVehicle = true;
      _fastFixes = 0;
      _slowSince = null;
      return VehicleChange(inVehicle: true, since: _rideStart(start));
    }
    if (speed >= thresholds.exitMps) {
      _slowSince = null;
      return null;
    }
    final since = _slowSince ??= now;
    if (now.difference(since) < thresholds.exitAfter) return null;
    _inVehicle = false;
    _slowSince = null;
    return VehicleChange(inVehicle: false, since: _rideEnd(since));
  }

  /// Accurate fixes from [since] on, to fill the track back in after
  /// leaving a vehicle.
  List<TrackPoint> fixesSince(DateTime since) =>
      _recent.where((p) => !p.timestamp.isBefore(since)).toList();

  /// Forgets everything (manual pause or "I'm still running").
  void reset() {
    _recent.clear();
    _inVehicle = false;
    _fastFixes = 0;
    _slowSince = null;
  }

  /// The window starts before the ride did: skip its slow steps, so the
  /// running before it still counts.
  DateTime _rideStart(TrackPoint windowStart) {
    var i = _recent.indexOf(windowStart);
    while (i < _recent.length - 1 && _stepMps(i) < thresholds.exitMps) {
      i++;
    }
    return _recent[i].timestamp;
  }

  /// The window turns slow after the vehicle stopped: go back over the
  /// slow steps to when it did.
  DateTime _rideEnd(DateTime slowSince) {
    var i = _recent.indexWhere((p) => !p.timestamp.isBefore(slowSince));
    if (i < 0) return slowSince;
    while (i > 0 && _stepMps(i - 1) < thresholds.exitMps) {
      i--;
    }
    return _recent[i].timestamp;
  }

  /// Speed from fix [i] to the next one (timestamps strictly increase).
  double _stepMps(int i) {
    final a = _recent[i];
    final b = _recent[i + 1];
    final seconds = b.timestamp.difference(a.timestamp).inMilliseconds / 1000;
    return distanceBetween(a, b) / seconds;
  }

  /// The first fix of the window ending at [end] and the speed across it;
  /// null while it spans less than [VehicleThresholds.minSpan].
  (TrackPoint, double)? _window(DateTime end) {
    final from = end.subtract(thresholds.window);
    final start = _recent.firstWhere((p) => !p.timestamp.isBefore(from));
    final span = end.difference(start.timestamp);
    if (span < thresholds.minSpan) return null;
    final speed =
        distanceBetween(start, _recent.last) / (span.inMilliseconds / 1000);
    return (start, speed);
  }
}
