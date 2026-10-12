import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../../core/network/token_store.dart';
import '../../activity/data/datasources/app_database.dart';
import '../../activity/domain/entities/activity.dart';
import '../../activity/domain/entities/activity_type.dart';
import '../../activity/domain/entities/track_point.dart';
import '../../activity/domain/repositories/activity_repository.dart';
import '../../activity/domain/services/uuid.dart';
import '../domain/entities/gps_simulation.dart';
import '../domain/services/debug_tools.dart';
import '../domain/services/route_simulator.dart';
import 'debug_http_client.dart';
import 'simulated_location_tracker.dart';
import 'virtual_clock.dart';

class DeviceDebugTools implements DebugTools {
  DeviceDebugTools({
    required Database database,
    required ActivityRepository activities,
    required TokenStore tokens,
    required SimulatedLocationTracker tracker,
    required VirtualClock clock,
    required DebugHttpClient http,
  }) : _db = database,
       _activities = activities,
       _tokens = tokens,
       _tracker = tracker,
       _clock = clock,
       _http = http;

  final Database _db;
  final ActivityRepository _activities;
  final TokenStore _tokens;
  final SimulatedLocationTracker _tracker;
  final VirtualClock _clock;
  final DebugHttpClient _http;
  final _random = math.Random();

  @override
  GpsSimulation get gps => _tracker.settings;

  @override
  void setGps(GpsSimulation value) {
    _tracker.settings = value;
    if (value.enabled) {
      _clock.speed = value.speed;
    } else {
      _clock.reset();
    }
  }

  @override
  void dropGpsSignal() => _tracker.dropSignal();

  @override
  bool get offline => _http.offline;

  @override
  void setOffline(bool value) => _http.offline = value;

  @override
  void expireAccessTokenOnce() => _http.expireNext = true;

  @override
  Future<void> breakSession() async {
    final session = await _tokens.read();
    if (session == null) return;
    await _tokens.write(
      StoredSession(
        accessToken: session.accessToken,
        refreshToken: 'debug-broken-refresh-token',
        userId: session.userId,
        email: session.email,
      ),
    );
    _http.expireNext = true;
  }

  @override
  Future<int> pendingSyncCount() async {
    final owner = (await _tokens.read())?.userId;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${AppDatabase.activitiesTable} '
      'WHERE synced = 0 AND (owner_id IS NULL OR owner_id = ?)',
      [owner],
    );
    return rows.first['n']! as int;
  }

  @override
  Future<int> seedActivities({int count = 10}) async {
    final now = DateTime.now();
    for (var i = 0; i < count; i++) {
      final type = ActivityType.values[_random.nextInt(3)];
      final (route, pace, km) = switch (type) {
        ActivityType.run => (
          _random.nextBool() ? SimRoute.lumpini : SimRoute.riverside,
          270 + _random.nextInt(150),
          3 + _random.nextDouble() * 9,
        ),
        ActivityType.ride => (
          SimRoute.riverside,
          100 + _random.nextInt(60),
          15 + _random.nextDouble() * 25,
        ),
        ActivityType.hike => (
          SimRoute.doiSuthep,
          600 + _random.nextInt(300),
          4 + _random.nextDouble() * 6,
        ),
      };
      // Spread over the last three weeks, at a plausible hour.
      final day = now.subtract(Duration(days: _random.nextInt(21)));
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        6 + _random.nextInt(13),
        _random.nextInt(60),
      );
      final activity = _generate(type, route, pace, km * 1000, start);
      await _activities.save(activity);
    }
    return count;
  }

  /// One fix every 5 s, with a pause half way through.
  Activity _generate(
    ActivityType type,
    SimRoute route,
    int paceSecondsPerKm,
    double meters,
    DateTime start,
  ) {
    final simulator = RouteSimulator(route, random: _random);
    const step = 5;
    final metersPerStep = step * 1000 / paceSecondsPerKm;
    final steps = (meters / metersPerStep).ceil();
    const pause = Duration(minutes: 2);
    final segments = <List<TrackPoint>>[[], []];
    for (var i = 0; i <= steps; i++) {
      final second = i < steps / 2
          ? Duration(seconds: i * step)
          : Duration(seconds: i * step) + pause;
      segments[i < steps / 2 ? 0 : 1].add(
        simulator.pointAt(i * metersPerStep, start.add(second)),
      );
    }
    final moving = Duration(seconds: steps * step);
    return Activity(
      id: uuidV4(),
      type: type,
      title: 'ทดสอบ ${type.name} #${_random.nextInt(900) + 100}',
      startedAt: start,
      endedAt: start.add(moving + pause),
      movingTime: moving,
      segments: segments,
    );
  }

  @override
  Future<void> clearLocalData() => _db.transaction((txn) async {
    await txn.delete(AppDatabase.trackPointsTable);
    await txn.delete(AppDatabase.activitiesTable);
    await txn.delete(AppDatabase.syncStateTable);
    await txn.delete(AppDatabase.shoesTable);
    await txn.delete(AppDatabase.workoutsTable);
    // Profiles and caches; the distance unit is a device setting and stays.
    await txn.delete(AppDatabase.kvTable, where: "key <> 'settings'");
  });
}
