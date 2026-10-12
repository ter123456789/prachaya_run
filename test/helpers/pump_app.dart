import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/app.dart';

import 'fakes.dart';

/// Every port of the app, as in-memory fakes a test can inspect.
class TestApp {
  final activities = InMemoryActivityRepository();
  final shoes = InMemoryShoeRepository();
  final workouts = InMemoryWorkoutRepository();
  final settings = InMemorySettingsRepository();
  final profile = FakeProfileRepository();
  final auth = FakeAuthRepository();

  /// Pumps the whole app on a phone-sized screen with reduced motion (so
  /// looping animations stop and pumpAndSettle ends).
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      PrachayaRunApp(
        activityRepository: activities,
        activitySync: FakeActivitySync(),
        authRepository: auth,
        profileRepository: profile,
        photoRepository: InMemoryPhotoRepository(),
        shoeRepository: shoes,
        workoutRepository: workouts,
        settingsRepository: settings,
        locationTracker: FakeLocationTracker(),
        photoSource: FakePhotoSource(),
        imageSink: FakeImageSink(),
      ),
    );
    await tester.pumpAndSettle();
  }
}
