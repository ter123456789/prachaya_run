import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/token_store.dart';
import 'core/storage/kv_store.dart';
import 'core/sync/record_sync_participant.dart';
import 'core/sync/synced_record_store.dart';
import 'features/activity/data/datasources/activity_local_data_source.dart';
import 'features/activity/data/datasources/activity_remote_data_source.dart';
import 'features/activity/data/datasources/app_database.dart';
import 'features/activity/data/datasources/photo_local_data_source.dart';
import 'features/activity/data/repositories/http_challenge_repository.dart';
import 'features/activity/data/repositories/offline_first_activity_repository.dart';
import 'features/activity/data/repositories/offline_first_photo_repository.dart';
import 'features/activity/data/services/android_recording_notification.dart';
import 'features/activity/data/services/geolocator_location_tracker.dart';
import 'features/activity/data/services/ios_live_activity_mirror.dart';
import 'features/activity/data/services/tts_voice_coach.dart';
import 'features/activity/data/services/open_meteo_weather_service.dart';
import 'features/activity/data/sync/activity_sync_engine.dart';
import 'features/activity/data/sync/device_guest_data.dart';
import 'features/auth/data/repositories/http_auth_repository.dart';
import 'features/auth/data/services/social_credentials.dart';
import 'features/athlete/data/repositories/kv_settings_repository.dart';
import 'features/athlete/data/repositories/offline_first_shoe_repository.dart';
import 'features/auth/data/repositories/local_first_profile_repository.dart';
import 'features/auth/data/sync/profile_store.dart';
import 'features/auth/data/sync/profile_sync.dart';
import 'features/debug/data/debug_http_client.dart';
import 'features/debug/data/device_debug_tools.dart';
import 'features/debug/data/simulated_location_tracker.dart';
import 'features/debug/data/virtual_clock.dart';
import 'features/photo_share/data/services/device_image_sink.dart';
import 'features/photo_share/data/services/image_picker_photo_source.dart';
import 'features/reminders/data/kv_reminder_settings_repository.dart';
import 'features/reminders/data/local_notification_scheduler.dart';
import 'features/training/data/repositories/offline_first_workout_repository.dart';

/// Composition root: the only place that knows concrete implementations.
/// Debug-only tools sit behind `kDebugMode`, so release builds drop them.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final tokens = SecureTokenStore();
  final debugHttp = kDebugMode ? DebugHttpClient() : null;
  final api = ApiClient(
    baseUrl: apiBaseUrl,
    tokens: tokens,
    httpClient: debugHttp,
  );
  final kv = KvStore(database);
  final local = ActivityLocalDataSource(database);
  final photos = PhotoLocalDataSource(
    database,
    Directory('${(await getApplicationDocumentsDirectory()).path}/photos'),
  );
  final profiles = ProfileStore(kv);
  final shoes = SyncedRecordStore(database, AppDatabase.shoesTable);
  final workouts = SyncedRecordStore(database, AppDatabase.workoutsTable);
  final sync = ActivitySyncEngine(
    local: local,
    remote: ActivityRemoteDataSource(api),
    photos: photos,
    tokens: tokens,
    participants: [
      ProfileSync(profiles, api),
      RecordSyncParticipant(shoes, api, path: '/shoes'),
      RecordSyncParticipant(workouts, api, path: '/workouts'),
    ],
  );
  final activities = OfflineFirstActivityRepository(
    local,
    sync,
    tokens,
    photos: photos,
  );

  final notifications = LocalNotificationScheduler();
  final realTracker = GeolocatorLocationTracker();
  final clock = kDebugMode ? VirtualClock() : null;
  final simTracker = kDebugMode
      ? SimulatedLocationTracker(realTracker, clock!)
      : null;

  runApp(
    PrachayaRunApp(
      activityRepository: activities,
      activitySync: sync,
      authRepository: HttpAuthRepository(
        api,
        tokens,
        social: PluginSocialCredentialSource(),
        onAccountDeleted: (userId) async {
          await local.purgeOwner(userId);
          await photos.pruneOrphans();
          await shoes.purgeOwner(userId);
          await workouts.purgeOwner(userId);
          await profiles.remove(userId);
        },
      ),
      profileRepository: LocalFirstProfileRepository(
        profiles,
        tokens,
        scheduleSync: sync.schedule,
      ),
      shoeRepository: OfflineFirstShoeRepository(
        shoes,
        tokens,
        scheduleSync: sync.schedule,
      ),
      workoutRepository: OfflineFirstWorkoutRepository(
        workouts,
        tokens,
        scheduleSync: sync.schedule,
      ),
      settingsRepository: KvSettingsRepository(kv),
      reminderScheduler: notifications,
      recordingMirror: Platform.isIOS
          ? IosLiveActivityMirror()
          : Platform.isAndroid
          ? AndroidRecordingNotification(notifications)
          : null,
      voiceCoach: TtsVoiceCoach(),
      reminderSettings: KvReminderSettingsRepository(kv),
      guestData: DeviceGuestData(
        activities: local,
        photos: photos,
        shoes: shoes,
        workouts: workouts,
        profiles: profiles,
        sync: sync,
      ),
      photoRepository: OfflineFirstPhotoRepository(photos, sync, tokens),
      challengeRepository: HttpChallengeRepository(api, tokens, kv),
      weatherService: OpenMeteoWeatherService(http.Client(), kv),
      locationTracker: simTracker ?? realTracker,
      photoSource: ImagePickerPhotoSource(),
      imageSink: DeviceImageSink(),
      clock: clock?.now,
      debugTools: kDebugMode
          ? DeviceDebugTools(
              database: database,
              activities: activities,
              tokens: tokens,
              tracker: simTracker!,
              clock: clock!,
              http: debugHttp!,
            )
          : null,
    ),
  );
}
