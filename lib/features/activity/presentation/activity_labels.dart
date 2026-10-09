import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../domain/entities/activity_type.dart';

extension ActivityTypeLabels on ActivityType {
  String get label => switch (this) {
    ActivityType.run => 'วิ่ง',
    ActivityType.ride => 'ปั่นจักรยาน',
    ActivityType.hike => 'เดินป่า',
  };

  IconData get icon => switch (this) {
    ActivityType.run => Icons.directions_run,
    ActivityType.ride => Icons.directions_bike,
    ActivityType.hike => Icons.hiking,
  };

  /// Runs and hikes show pace (min/km); rides show speed (km/h).
  bool get usesPace => this != ActivityType.ride;
}

String defaultActivityTitle(ActivityType type, DateTime startedAt) {
  return '${type.label}${timeOfDayPeriod(startedAt)}';
}
