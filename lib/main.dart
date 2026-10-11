import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/token_store.dart';
import 'features/activity/data/datasources/activity_local_data_source.dart';
import 'features/activity/data/datasources/activity_remote_data_source.dart';
import 'features/activity/data/datasources/app_database.dart';
import 'features/activity/data/datasources/photo_local_data_source.dart';
import 'features/activity/data/repositories/offline_first_activity_repository.dart';
import 'features/activity/data/services/geolocator_location_tracker.dart';
import 'features/activity/data/sync/activity_sync_engine.dart';
import 'features/auth/data/repositories/http_auth_repository.dart';
import 'features/debug/data/debug_http_client.dart';
import 'features/debug/data/device_debug_tools.dart';
import 'features/debug/data/simulated_location_tracker.dart';
import 'features/debug/data/virtual_clock.dart';
import 'features/photo_share/data/services/device_image_sink.dart';
import 'features/photo_share/data/services/image_picker_photo_source.dart';

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
  final local = ActivityLocalDataSource(database);
  final photos = PhotoLocalDataSource(
    database,
    Directory('${(await getApplicationDocumentsDirectory()).path}/photos'),
  );
  final sync = ActivitySyncEngine(
    local: local,
    remote: ActivityRemoteDataSource(api),
    photos: photos,
    tokens: tokens,
  );
  final activities = OfflineFirstActivityRepository(
    local,
    sync,
    tokens,
    photos: photos,
  );

  final realTracker = GeolocatorLocationTracker();
  final clock = kDebugMode ? VirtualClock() : null;
  final simTracker = kDebugMode
      ? SimulatedLocationTracker(realTracker, clock!)
      : null;

  runApp(
    PrachayaRunApp(
      activityRepository: activities,
      activitySync: sync,
      authRepository: HttpAuthRepository(api, tokens),
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
