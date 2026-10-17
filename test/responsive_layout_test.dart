import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/layout/content_width.dart';
import 'package:prachaya_run/features/activity/presentation/pages/activity_detail_page.dart';
import 'package:prachaya_run/features/activity/presentation/pages/home_page.dart';
import 'package:prachaya_run/features/athlete/presentation/pages/profile_page.dart';
import 'package:prachaya_run/features/auth/presentation/pages/account_page.dart';
import 'package:prachaya_run/features/photo_share/presentation/pages/photo_overlay_page.dart';
import 'package:prachaya_run/features/training/presentation/pages/schedule_page.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

/// iPhone Duo (foldable): the outer screen with its camera strip on the
/// right, and the inner screen upright and sideways. Any overflow fails.
const _screens = {
  'outer': (Size(466, 678), EdgeInsets.fromLTRB(0, 20, 84, 20)),
  'inner': (Size(669, 951), EdgeInsets.fromLTRB(0, 32, 0, 20)),
  'inner landscape': (Size(951, 669), EdgeInsets.fromLTRB(32, 0, 0, 20)),
};

void main() {
  setUpAll(() {
    // The detail map's tile cache asks for a cache directory.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.createTempSync('tiles').path,
        );
  });

  test('content gutters centre a capped column', () {
    expect(contentGutters(393), const EdgeInsets.symmetric(horizontal: 16));
    expect(contentGutters(951).horizontal, 951 - Breakpoints.content);
    expect(Breakpoints.isTwoPane(669), isFalse);
    expect(Breakpoints.isTwoPane(951), isTrue);
  });

  for (final MapEntry(key: name, value: (size, padding)) in _screens.entries) {
    testWidgets('every page fits the iPhone Duo $name screen', (tester) async {
      final app = TestApp();
      final activity = sampleActivity();
      app.activities.store[activity.id] = activity;
      await app.pump(tester);
      tester.view.physicalSize = size * 3;
      tester.view.padding = FakeViewPadding(
        left: padding.left * 3,
        top: padding.top * 3,
        right: padding.right * 3,
        bottom: padding.bottom * 3,
      );
      await tester.pumpAndSettle();
      expect(find.text('พร้อมออกไปวิ่งหรือยัง?'), findsOneWidget);

      await tester.tap(find.byTooltip('ประวัติ'));
      await tester.pumpAndSettle();
      expect(find.text('ตุลาคม 2569'), findsOneWidget);

      final navigator = Navigator.of(tester.element(find.byType(HomePage)));
      for (final route in [
        ActivityDetailPage.route(activity.id),
        ProfilePage.route(),
        SchedulePage.route(),
        AccountPage.route(),
        PhotoOverlayPage.route(activity),
      ]) {
        navigator.push(route);
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('เริ่มบันทึก'));
      await tester.pumpAndSettle();
      expect(find.text('บันทึกกิจกรรม'), findsOneWidget);
      expect(find.byTooltip('เริ่ม'), findsOneWidget);
    });
  }
}
