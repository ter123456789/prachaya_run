import '../../../activity/domain/services/location_tracker.dart';

/// Built-in test routes (lat, lng, altitude).
enum SimRoute {
  /// ~2.4 km flat loop around Lumpini Park, Bangkok.
  lumpini,

  /// Out-and-back along the Chao Phraya riverside.
  riverside,

  /// ~6 km climb up Doi Suthep, Chiang Mai (~650 m gain), then back down.
  doiSuthep,
}

/// How the debug GPS behaves. Disabled means the real GPS is used.
class GpsSimulation {
  const GpsSimulation({
    this.enabled = false,
    this.route = SimRoute.lumpini,
    this.paceSecondsPerKm = 330,
    this.speed = 10,
    this.noise = true,
    this.access = LocationAccess.granted,
  });

  final bool enabled;
  final SimRoute route;

  /// 330 = 5:30 min/km. 120 ≈ 30 km/h for rides.
  final int paceSecondsPerKm;

  /// Time runs this many times faster than real time while simulating.
  final int speed;

  /// Adds GPS jitter, altitude wobble and the odd inaccurate fix.
  final bool noise;

  /// What a location permission request answers (to test failures).
  final LocationAccess access;

  GpsSimulation copyWith({
    bool? enabled,
    SimRoute? route,
    int? paceSecondsPerKm,
    int? speed,
    bool? noise,
    LocationAccess? access,
  }) => GpsSimulation(
    enabled: enabled ?? this.enabled,
    route: route ?? this.route,
    paceSecondsPerKm: paceSecondsPerKm ?? this.paceSecondsPerKm,
    speed: speed ?? this.speed,
    noise: noise ?? this.noise,
    access: access ?? this.access,
  );

  @override
  bool operator ==(Object other) =>
      other is GpsSimulation &&
      other.enabled == enabled &&
      other.route == route &&
      other.paceSecondsPerKm == paceSecondsPerKm &&
      other.speed == speed &&
      other.noise == noise &&
      other.access == access;

  @override
  int get hashCode =>
      Object.hash(enabled, route, paceSecondsPerKm, speed, noise, access);
}
