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
import 'package:prachaya_run/features/auth/domain/entities/user_profile.dart';
import 'package:prachaya_run/features/auth/domain/repositories/profile_repository.dart';
import 'package:prachaya_run/features/auth/domain/services/profile_validation.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/features/athlete/domain/entities/shoe.dart';
import 'package:prachaya_run/features/athlete/domain/repositories/settings_repository.dart';
import 'package:prachaya_run/features/athlete/domain/repositories/shoe_repository.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:prachaya_run/features/training/domain/repositories/workout_repository.dart';
import 'package:prachaya_run/features/training/domain/services/workout_plan.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_photo.dart';
import 'package:prachaya_run/features/activity/domain/repositories/activity_photo_repository.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/domain/services/debug_tools.dart';
import 'package:prachaya_run/features/photo_share/domain/services/image_sink.dart';
import 'package:prachaya_run/features/photo_share/domain/services/photo_source.dart';
import 'package:prachaya_run/features/auth/domain/entities/guest_data_summary.dart';
import 'package:prachaya_run/features/auth/domain/repositories/guest_data_repository.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder_settings.dart';
import 'package:prachaya_run/features/reminders/domain/repositories/reminder_scheduler.dart';
import 'package:prachaya_run/features/reminders/domain/repositories/reminder_settings_repository.dart';

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

  @override
  Future<void> setShoe(String id, String? shoeId) async {
    final a = store[id];
    if (a != null) store[id] = a.withShoe(shoeId);
  }
}

class FakeActivitySync implements ActivitySync {
  final changesController = StreamController<void>.broadcast();
  SyncOutcome next = SyncOutcome.synced;
  int calls = 0;

  @override
  Stream<void> get changes => changesController.stream;

  int pending = 0;

  @override
  Future<SyncOutcome> sync() async {
    calls++;
    return next;
  }

  @override
  Future<int> pendingCount() async => pending;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.providers = const {}});

  AuthUser? user;
  Set<SocialProvider> providers;
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
  Future<Set<SocialProvider>> availableProviders() async => providers;

  final socialSignIns = <SocialProvider>[];

  @override
  Future<AuthUser> signInWith(SocialProvider provider) {
    socialSignIns.add(provider);
    return _signIn('${provider.name}@example.com');
  }

  @override
  Future<void> logout() async => user = null;

  bool deleted = false;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    user = null;
  }
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

class FakeProfileRepository implements ProfileRepository {
  UserProfile profile = const UserProfile();

  @override
  Future<UserProfile> load() async => profile;

  @override
  Future<UserProfile> save(UserProfile p) async {
    final invalid = validateProfile(p, currentYear: 2026);
    if (invalid.isNotEmpty) throw ProfileValidationException(invalid);
    return profile = p;
  }
}

class InMemoryShoeRepository implements ShoeRepository {
  final Map<String, Shoe> store = {};

  @override
  Future<List<Shoe>> getAll() async => store.values.toList();

  @override
  Future<void> save(Shoe shoe) async {
    if (!isValidShoe(shoe)) throw const ShoeValidationException();
    if (shoe.primary) {
      for (final e in store.entries.toList()) {
        if (e.key != shoe.id) store[e.key] = e.value.copyWith(primary: false);
      }
    }
    store[shoe.id] = shoe;
  }

  @override
  Future<void> delete(String id) async => store.remove(id);

  @override
  Future<Shoe?> primary() async =>
      store.values.where((s) => s.primary && !s.retired).firstOrNull;
}

class InMemoryWorkoutRepository implements WorkoutRepository {
  final Map<String, PlannedWorkout> store = {};

  @override
  Future<List<PlannedWorkout>> getAll() async =>
      store.values.toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  @override
  Future<void> save(PlannedWorkout w) async {
    if (!isValidWorkout(w)) throw const WorkoutValidationException();
    store[w.id] = w;
  }

  @override
  Future<void> delete(String id) async => store.remove(id);
}

class InMemorySettingsRepository implements SettingsRepository {
  DistanceUnit unit = DistanceUnit.km;

  @override
  Future<DistanceUnit> distanceUnit() async => unit;

  @override
  Future<void> setDistanceUnit(DistanceUnit u) async => unit = u;
}

class InMemoryPhotoRepository implements ActivityPhotoRepository {
  final List<ActivityPhoto> photos = [];

  @override
  Future<List<ActivityPhoto>> photosOf(String activityId) async =>
      photos.where((p) => p.activityId == activityId).toList();

  @override
  Future<ActivityPhoto> add(
    String activityId,
    List<int> bytes, {
    required DateTime takenAt,
  }) async {
    final photo = ActivityPhoto(
      id: 'p${photos.length}',
      activityId: activityId,
      takenAt: takenAt,
    );
    photos.add(photo);
    return photo;
  }

  @override
  Future<void> delete(ActivityPhoto photo) async => photos.remove(photo);
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

class FakeGuestData implements GuestDataRepository {
  FakeGuestData([this.data = GuestDataSummary.empty]);

  GuestDataSummary data;
  final calls = <String>[];

  @override
  Future<GuestDataSummary> summary() async => data;

  @override
  Future<void> merge(String userId) async {
    calls.add('merge:$userId');
    data = GuestDataSummary.empty;
  }

  @override
  Future<void> keepOnDevice() async {
    calls.add('keep');
    data = GuestDataSummary.empty;
  }

  @override
  Future<void> restore() async => calls.add('restore');
}

class FakeReminderScheduler implements ReminderScheduler {
  bool allow = true;
  int permissionRequests = 0;
  final pending = <ReminderKind, List<Reminder>>{};
  final shown = <Reminder>[];
  final _taps = StreamController<ReminderTarget>.broadcast();
  ReminderTarget? launch;

  void tap(ReminderTarget target) => _taps.add(target);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allow;
  }

  @override
  Future<void> replace(ReminderKind kind, List<Reminder> reminders) async =>
      pending[kind] = List.of(reminders);

  @override
  Future<void> showNow(Reminder reminder) async => shown.add(reminder);

  @override
  Stream<ReminderTarget> get taps => _taps.stream;

  @override
  Future<ReminderTarget?> launchTarget() async => launch;
}

class InMemoryReminderSettings implements ReminderSettingsRepository {
  ReminderSettings settings = const ReminderSettings();

  @override
  Future<ReminderSettings> load() async => settings;

  @override
  Future<void> save(ReminderSettings s) async => settings = s;
}
