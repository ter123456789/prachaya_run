import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/app.dart';

import 'helpers/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    InMemoryActivityRepository repo, {
    FakeDebugTools? debugTools,
  }) async {
    // Phone-sized viewport.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Looping motion (pulse dots, shimmer) pauses under "reduce motion",
    // which also lets pumpAndSettle finish.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      PrachayaRunApp(
        activityRepository: repo,
        activitySync: FakeActivitySync(),
        authRepository: FakeAuthRepository(),
        profileRepository: FakeProfileRepository(),
        photoRepository: InMemoryPhotoRepository(),
        shoeRepository: InMemoryShoeRepository(),
        workoutRepository: InMemoryWorkoutRepository(),
        settingsRepository: InMemorySettingsRepository(),
        locationTracker: FakeLocationTracker(),
        photoSource: FakePhotoSource(),
        imageSink: FakeImageSink(),
        debugTools: debugTools,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state: dashboard, history and recorder', (tester) async {
    await pumpApp(tester, InMemoryActivityRepository());

    expect(find.text('พร้อมออกไปวิ่งหรือยัง?'), findsOneWidget);
    expect(find.text('ยังไม่มีกิจกรรม'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีกิจกรรม ออกไปวิ่งกัน!'), findsOneWidget);

    await tester.tap(find.byTooltip('เริ่มบันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกกิจกรรม'), findsOneWidget);
    expect(find.byTooltip('เริ่ม'), findsOneWidget);
  });

  testWidgets('dashboard and history show saved activities', (tester) async {
    final repo = InMemoryActivityRepository();
    final activity = sampleActivity();
    repo.store[activity.id] = activity;
    await pumpApp(tester, repo);

    expect(find.text('วิ่งตอนเช้า'), findsOneWidget); // latest activity card
    final km = (activity.distanceMeters / 1000).toStringAsFixed(2);
    expect(find.textContaining(km, findRichText: true), findsWidgets);

    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    expect(find.text('ตุลาคม 2569'), findsOneWidget);

    await tester.tap(find.text('ปั่นจักรยาน'));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีกิจกรรม ออกไปวิ่งกัน!'), findsOneWidget);
  });

  testWidgets('no debug button unless debug tools are given', (tester) async {
    await pumpApp(tester, InMemoryActivityRepository());
    expect(find.byIcon(Icons.bug_report_rounded), findsNothing);
  });

  testWidgets('debug button opens the panel; tools are wired', (tester) async {
    final tools = FakeDebugTools();
    await pumpApp(tester, InMemoryActivityRepository(), debugTools: tools);

    await tester.tap(find.byIcon(Icons.bug_report_rounded));
    await tester.pumpAndSettle();
    expect(find.text('เครื่องมือทดสอบ'), findsOneWidget);

    await tester.tap(find.text('ใช้ GPS จำลอง'));
    await tester.pumpAndSettle();
    expect(tools.gps.enabled, isTrue);
    expect(find.text('ดอยสุเทพ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('เพิ่มกิจกรรมตัวอย่าง 10 รายการ'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('เพิ่มกิจกรรมตัวอย่าง 10 รายการ'));
    await tester.pumpAndSettle();
    expect(tools.seeded, 10);

    await tester.scrollUntilVisible(
      find.text('ให้ access token หมดอายุ'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('ให้ access token หมดอายุ'));
    await tester.pumpAndSettle();
    expect(tools.expired, 1);
  });

  testWidgets('history card opens the redesigned detail screen', (
    tester,
  ) async {
    final repo = InMemoryActivityRepository();
    final activity = sampleActivity();
    repo.store[activity.id] = activity;
    await pumpApp(tester, repo);

    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    expect(find.text('ตุลาคม 2569'), findsOneWidget);
    expect(find.text('1 กิจกรรม'), findsOneWidget);

    await tester.tap(find.text('วิ่งตอนเช้า').last);
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดกิจกรรม'), findsOneWidget);
    expect(find.text('OUTDOOR RUN'), findsOneWidget);
    expect(find.text('ใส่เส้นทางและสถิติลงรูปภาพ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ภาพบันทึกหลังวิ่ง'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0 ภาพถ่าย'), findsOneWidget);
  });

  testWidgets('account screen: sign-in form with inline validation', (
    tester,
  ) async {
    await pumpApp(tester, InMemoryActivityRepository());
    // The avatar opens the profile; its sync strip leads to the account.
    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลผู้ใช้'), findsOneWidget);
    await tester.tap(find.text('เข้าสู่ระบบเพื่อซิงก์'));
    await tester.pumpAndSettle();

    expect(find.text('ซิงก์กิจกรรมข้ามเครื่อง'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'password1');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('การแจ้งเตือนรูปแบบ'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'me@run.co');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    expect(find.text('me@run.co'), findsOneWidget);
    expect(find.text('ซิงก์ตอนนี้'), findsOneWidget);
  });
}
