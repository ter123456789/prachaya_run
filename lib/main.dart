import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/token_store.dart';
import 'features/activity/data/datasources/activity_local_data_source.dart';
import 'features/activity/data/datasources/activity_remote_data_source.dart';
import 'features/activity/data/datasources/app_database.dart';
import 'features/activity/data/repositories/offline_first_activity_repository.dart';
import 'features/activity/data/services/geolocator_location_tracker.dart';
import 'features/activity/data/sync/activity_sync_engine.dart';
import 'features/auth/data/repositories/http_auth_repository.dart';
import 'features/photo_share/data/services/device_image_sink.dart';
import 'features/photo_share/data/services/image_picker_photo_source.dart';

/// Composition root: the only place that knows concrete implementations.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final tokens = SecureTokenStore();
  final api = ApiClient(baseUrl: apiBaseUrl, tokens: tokens);
  final local = ActivityLocalDataSource(database);
  final sync = ActivitySyncEngine(
    local: local,
    remote: ActivityRemoteDataSource(api),
    tokens: tokens,
  );
  runApp(
    PrachayaRunApp(
      activityRepository: OfflineFirstActivityRepository(local, sync, tokens),
      activitySync: sync,
      authRepository: HttpAuthRepository(api, tokens),
      locationTracker: GeolocatorLocationTracker(),
      photoSource: ImagePickerPhotoSource(),
      imageSink: DeviceImageSink(),
    ),
  );
}
