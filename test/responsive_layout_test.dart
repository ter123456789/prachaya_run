import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/layout/content_width.dart';
import 'package:prachaya_run/features/activity/presentation/pages/activity_detail_page.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_origin.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_monitor.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/heart_rate/heart_rate_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/record/record_bloc.dart';
import 'package:prachaya_run/features/activity/presentation/pages/home_page.dart';
import 'package:prachaya_run/features/activity/presentation/pages/record_page.dart';
import 'package:prachaya_run/features/athlete/presentation/pages/profile_page.dart';
import 'package:prachaya_run/features/auth/presentation/pages/account_page.dart';
import 'package:prachaya_run/features/photo_share/presentation/pages/photo_overlay_page.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/planned_route.dart';
import 'package:prachaya_run/features/route_builder/presentation/pages/route_draw_page.dart';
import 'package:prachaya_run/features/route_builder/presentation/pages/route_list_page.dart';
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
      final sample = sampleActivity();
      // With heart rate, so the detail page shows its card too.
      final activity = Activity(
        id: sample.id,
        type: sample.type,
        title: sample.title,
        startedAt: sample.startedAt,
        endedAt: sample.endedAt,
        movingTime: sample.movingTime,
        segments: sample.segments,
        heartRate: sampleHeartRate(),
      );
      app.activities.store[activity.id] = activity;
      // From a watch, without a GPS track.
      final watchRun = Activity(
        id: 'watch',
        type: ActivityType.run,
        title: '',
        startedAt: sample.startedAt.subtract(const Duration(days: 1)),
        endedAt: sample.endedAt.subtract(const Duration(days: 1)),
        movingTime: sample.movingTime,
        segments: const [],
        origin: const ActivityOrigin(
          OriginKind.health,
          app: 'Samsung Health',
          device: 'Galaxy Watch7 Ultra LTE',
        ),
        reportedDistanceMeters: 5000,
      );
      app.activities.store[watchRun.id] = watchRun;
      const route = PlannedRoute(
        id: 'r1',
        name: 'หัวใจรอบสวนลุมพินี วนสองรอบแล้วกลับบ้าน',
        drawn: [GeoPoint(13.73, 100.54), GeoPoint(13.735, 100.545)],
        route: [GeoPoint(13.73, 100.54), GeoPoint(13.735, 100.545)],
        distanceMeters: 7342,
        score: 87,
      );
      app.routes.store[route.id] = route;
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
        ActivityDetailPage.route(watchRun.id),
        PhotoOverlayPage.route(watchRun),
        ProfilePage.route(),
        SchedulePage.route(),
        AccountPage.route(),
        PhotoOverlayPage.route(activity),
        RouteListPage.route(),
        RouteDrawPage.route(),
        RouteDrawPage.route(route: route),
      ]) {
        navigator.push(route);
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
      }

      // A connected sensor adds a bpm pill and tile on the record page.
      tester
          .element(find.byType(HomePage))
          .read<HeartRateCubit>()
          .connect(const HeartRateSensor(id: 'h', name: 'Polar H10'));
      await tester.pumpAndSettle();
      app.heartRate
        ..emitStatus(SensorLink.connected)
        ..emitReading(142);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('เริ่มบันทึก'));
      await tester.pumpAndSettle();
      expect(find.text('บันทึกกิจกรรม'), findsOneWidget);
      expect(find.byTooltip('เริ่ม'), findsOneWidget);
      expect(find.text('ชีพจร'), findsOneWidget);

      // Recording paused by a car ride, with its notice over the track.
      await tester.tap(find.byTooltip('เริ่ม'));
      await tester.pumpAndSettle();
      for (final fix in journey([(30, 3.5), (30, 15)])) {
        app.tracker.emit(fix);
      }
      await tester.pumpAndSettle();
      expect(find.text('ดูเหมือนคุณอยู่บนยานพาหนะ'), findsOneWidget);
      expect(find.text('อยู่บนยานพาหนะ'), findsOneWidget);
      tester
          .element(find.byType(RecordPage))
          .read<RecordBloc>()
          .add(const RecordReset());
      // The ticker's cancel completes on the real microtask queue.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    });
  }
}
