import 'package:flutter/material.dart';

import 'app.dart';
import 'features/activity/data/datasources/app_database.dart';
import 'features/activity/data/repositories/sqflite_activity_repository.dart';
import 'features/activity/data/services/geolocator_location_tracker.dart';
import 'features/photo_share/data/services/device_image_sink.dart';
import 'features/photo_share/data/services/image_picker_photo_source.dart';

/// Composition root: the only place that knows concrete implementations.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  runApp(
    PrachayaRunApp(
      activityRepository: SqfliteActivityRepository(database),
      locationTracker: GeolocatorLocationTracker(),
      photoSource: ImagePickerPhotoSource(),
      imageSink: DeviceImageSink(),
    ),
  );
}
