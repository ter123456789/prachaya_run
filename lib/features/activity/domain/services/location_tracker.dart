import '../entities/activity_type.dart';
import '../entities/track_point.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Port for the device GPS.
abstract interface class LocationTracker {
  Future<LocationAccess> requestAccess();

  Stream<TrackPoint> watch(ActivityType type);
}
