import 'dart:async';
import 'dart:typed_data';

import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/repositories/activity_repository.dart';
import 'package:prachaya_run/features/activity/domain/services/activity_sync.dart';
import 'package:prachaya_run/features/activity/domain/services/location_tracker.dart';
import 'package:prachaya_run/features/auth/domain/entities/auth_user.dart';
import 'package:prachaya_run/features/auth/domain/repositories/auth_repository.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/domain/services/debug_tools.dart';
import 'package:prachaya_run/features/photo_share/domain/services/image_sink.dart';
import 'package:prachaya_run/features/photo_share/domain/services/photo_source.dart';

final t0 = DateTime(2026, 10, 9, 6, 30);

/// Points heading north; 0.001° latitude ≈ 111.2 m.
TrackPoint pointAt(
  int i, {
  double? altitude,
  double? accuracy,
  int secondsPerStep = 30,
}) => TrackPoint(
  latitude: 13.7 + i * 0.001,
  longitude: 100.5,
  timestamp: t0.add(Duration(seconds: i * secondsPerStep)),
  altitudeMeters: altitude,
  accuracyMeters: accuracy,
);

class FakeLocationTracker implements LocationTracker {
  FakeLocationTracker({this.access = LocationAccess.granted});

  LocationAccess access;
  StreamController<TrackPoint>? controller;

  void emit(TrackPoint point) => controller!.add(point);
  void fail() => controller!.addError(Exception('gps lost'));

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Stream<TrackPoint> watch(ActivityType type) {
    controller = StreamController<TrackPoint>();
    return controller!.stream;
  }
}

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, Activity> store = {};

  @override
  Future<void> save(Activity activity) async => store[activity.id] = activity;

  @override
  Future<List<ActivitySummary>> getAll() async =>
      (store.values.toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
          .map((a) => a.summary)
          .toList();

  @override
  Future<Activity?> getById(String id) async => store[id];

  @override
  Future<void> delete(String id) async => store.remove(id);
}

class FakeActivitySync implements ActivitySync {
  final changesController = StreamController<void>.broadcast();
  SyncOutcome next = SyncOutcome.synced;
  int calls = 0;

  @override
  Stream<void> get changes => changesController.stream;

  @override
  Future<SyncOutcome> sync() async {
    calls++;
    return next;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  AuthUser? user;
  AuthError? failNext;
  final _changes = StreamController<AuthUser?>.broadcast();

  void endSession() {
    user = null;
    _changes.add(null);
  }

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser?> currentUser() async => user;

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      _signIn(email);

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
  }) => _signIn(email);

  Future<AuthUser> _signIn(String email) async {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw AuthException(error);
    }
    return user = AuthUser(id: 'u1', email: email);
  }

  @override
  Future<void> logout() async => user = null;
}

class FakeDebugTools implements DebugTools {
  @override
  GpsSimulation gps = const GpsSimulation();
  @override
  bool offline = false;
  int seeded = 0;
  int expired = 0;

  @override
  void setGps(GpsSimulation value) => gps = value;
  @override
  void dropGpsSignal() {}
  @override
  void setOffline(bool value) => offline = value;
  @override
  void expireAccessTokenOnce() => expired++;
  @override
  Future<void> breakSession() async {}
  @override
  Future<int> pendingSyncCount() async => 0;
  @override
  Future<int> seedActivities({int count = 10}) async => seeded += count;
  @override
  Future<void> clearLocalData() async {}
}

class FakePhotoSource implements PhotoSource {
  Uint8List? next;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async => next;
}

class FakeImageSink implements ImageSink {
  final List<Uint8List> saved = [];
  final List<Uint8List> shared = [];
  bool denySave = false;

  @override
  Future<void> saveToGallery(Uint8List png, {required String name}) async {
    if (denySave) throw const ImageSinkPermissionDenied();
    saved.add(png);
  }

  @override
  Future<void> share(
    Uint8List png, {
    required String name,
    ShareAnchor? anchor,
  }) async => shared.add(png);
}

Activity sampleActivity({ActivityType type = ActivityType.run}) => Activity(
  id: 'a1',
  type: type,
  title: 'วิ่งตอนเช้า',
  startedAt: t0,
  endedAt: t0.add(const Duration(minutes: 30)),
  movingTime: const Duration(minutes: 28, seconds: 30),
  segments: [
    [for (var i = 0; i < 10; i++) pointAt(i)],
    [
      for (var i = 0; i < 10; i++)
        TrackPoint(
          latitude: 13.709,
          longitude: 100.5 + i * 0.001,
          timestamp: t0.add(Duration(minutes: 10 + i)),
        ),
    ],
  ],
);
