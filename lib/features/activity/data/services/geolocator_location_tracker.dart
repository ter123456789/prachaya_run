import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../domain/entities/activity_type.dart';
import '../../domain/entities/track_point.dart';
import '../../domain/services/location_tracker.dart';

class GeolocatorLocationTracker implements LocationTracker {
  @override
  Future<LocationAccess> requestAccess() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return switch (permission) {
      geo.LocationPermission.always ||
      geo.LocationPermission.whileInUse => LocationAccess.granted,
      geo.LocationPermission.deniedForever => LocationAccess.deniedForever,
      geo.LocationPermission.denied ||
      geo.LocationPermission.unableToDetermine => LocationAccess.denied,
    };
  }

  @override
  Stream<TrackPoint> watch(ActivityType type) {
    return geo.Geolocator.getPositionStream(
      locationSettings: _settingsFor(type),
    ).map(
      (position) => TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        altitudeMeters: position.altitude,
        accuracyMeters: position.accuracy,
      ),
    );
  }

  geo.LocationSettings _settingsFor(ActivityType type) {
    final distanceFilter = type == ActivityType.ride ? 5 : 3;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => geo.AndroidSettings(
        accuracy: geo.LocationAccuracy.best,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 1),
        // Keeps recording while the screen is off.
        foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
          notificationTitle: 'Prachaya Run',
          notificationText: 'กำลังบันทึกกิจกรรม',
          enableWakeLock: true,
        ),
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => geo.AppleSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        activityType: type == ActivityType.ride
            ? geo.ActivityType.otherNavigation
            : geo.ActivityType.fitness,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      ),
      _ => geo.LocationSettings(
        accuracy: geo.LocationAccuracy.best,
        distanceFilter: distanceFilter,
      ),
    };
  }
}
