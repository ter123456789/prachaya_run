import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/app.dart';

import 'helpers/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    InMemoryActivityRepository repo,
  ) async {
    // Phone-sized viewport.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PrachayaRunApp(
        activityRepository: repo,
        locationTracker: FakeLocationTracker(),
        photoSource: FakePhotoSource(),
        imageSink: FakeImageSink(),
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
    expect(
      find.text('${(activity.distanceMeters / 1000).toStringAsFixed(2)} กม.'),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    expect(find.text('ตุลาคม 2569'), findsOneWidget);

    await tester.tap(find.text('ปั่นจักรยาน'));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีกิจกรรม ออกไปวิ่งกัน!'), findsOneWidget);
  });
}
