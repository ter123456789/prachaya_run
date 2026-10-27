import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../domain/entities/activity_insights.dart';
import '../domain/entities/activity_origin.dart';
import '../domain/entities/activity_type.dart';
import '../domain/entities/weather_report.dart';

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

/// The title to show: activities imported by the server arrive untitled
/// (api.md v1.6) and get the default one.
String activityTitle(String title, ActivityType type, DateTime startedAt) =>
    title.trim().isEmpty ? defaultActivityTitle(type, startedAt) : title;

extension ActivityOriginLabels on ActivityOrigin {
  /// "Samsung Health", "Polar", … null for activities recorded here.
  String? get label => isPhone
      ? null
      : app ??
            switch (kind) {
              OriginKind.polar => 'Polar',
              OriginKind.garmin => 'Garmin',
              _ => device ?? 'นาฬิกา',
            };
}

extension EffortLabels on Effort {
  String tag(ActivityType type) {
    final sport = switch (type) {
      ActivityType.run => 'Run',
      ActivityType.ride => 'Ride',
      ActivityType.hike => 'Hike',
    };
    return switch (this) {
      Effort.easy => 'Easy $sport',
      Effort.steady => 'Steady $sport',
      Effort.tempo => 'Tempo $sport',
    };
  }
}

extension WeatherLabels on WeatherReport {
  String get description => switch (kind) {
    WeatherKind.clear => isNight ? 'ฟ้าโปร่ง' : 'แดดดี',
    WeatherKind.cloudy => 'มีเมฆบางส่วน',
    WeatherKind.fog => 'มีหมอก',
    WeatherKind.drizzle => 'ฝนปรอยๆ',
    WeatherKind.rain => 'ฝนตก',
    WeatherKind.storm => 'พายุฝนฟ้าคะนอง',
  };

  IconData get icon => switch (kind) {
    WeatherKind.clear =>
      isNight ? Icons.nightlight_round : Icons.wb_sunny_outlined,
    WeatherKind.cloudy => Icons.cloud_outlined,
    WeatherKind.fog => Icons.foggy,
    WeatherKind.drizzle || WeatherKind.rain => Icons.water_drop_outlined,
    WeatherKind.storm => Icons.thunderstorm_outlined,
  };

  String get temperatureLabel => '${temperatureC.round()}°C';
}

extension RunAdviceLabels on RunAdvice {
  String get headline => switch (this) {
    RunAdvice.great => 'อากาศดี เหมาะออกไปวิ่ง',
    RunAdvice.hot => 'ค่อนข้างร้อน ดื่มน้ำให้พอ',
    RunAdvice.veryHot => 'ร้อนจัด เลี่ยงการวิ่งหนัก',
    RunAdvice.wet => 'ฝนตก ระวังพื้นลื่น',
    RunAdvice.windy => 'ลมแรง เลือกเส้นทางที่บังลม',
  };

  String get hint => switch (this) {
    RunAdvice.great => 'เหมาะกับการวิ่งโซน 2 สบายๆ',
    RunAdvice.hot => 'ลดเพซลงเล็กน้อย พักบ่อยขึ้น',
    RunAdvice.veryHot => 'ออกช่วงเช้ามืดหรือหลังพระอาทิตย์ตก',
    RunAdvice.wet => 'ใส่รองเท้าที่ยึดเกาะดี',
    RunAdvice.windy => 'วิ่งทวนลมช่วงแรก กลับตามลม',
  };
}
