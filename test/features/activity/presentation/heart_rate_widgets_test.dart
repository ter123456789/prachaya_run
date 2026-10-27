import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_monitor.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('pair a sensor from the record page and see live bpm', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.byTooltip('เริ่มบันทึก'));
    await tester.pumpAndSettle();

    // No sensor yet: elevation tile, and a pill that opens the sheet.
    expect(find.text('ขึ้นสะสม'), findsOneWidget);
    await tester.tap(find.byTooltip('เซนเซอร์ชีพจร'));
    await tester.pumpAndSettle();
    expect(find.text('เซนเซอร์ชีพจร'), findsWidgets);
    expect(app.heartRate.scanning, isNotNull);

    app.heartRate.scanning!.add(const [
      HeartRateSensor(id: 'w', name: 'HUAWEI Band 9'),
      HeartRateSensor(id: 'h', name: 'Polar H10', advertisesHeartRate: true),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('อุปกรณ์อื่น'), findsOneWidget);

    await tester.tap(find.text('Polar H10'));
    await tester.pumpAndSettle();
    expect(app.heartRate.connected?.id, 'h');
    expect(find.text('กำลังเชื่อมต่อ…'), findsOneWidget);

    app.heartRate
      ..emitStatus(SensorLink.connected)
      ..emitReading(151, contact: true);
    await tester.pumpAndSettle();
    expect(find.text('เชื่อมต่อแล้ว'), findsOneWidget);

    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('ชีพจร'), findsOneWidget);
    expect(find.text('151'), findsWidgets);
    expect(find.text('ขึ้นสะสม'), findsNothing);
  });

  testWidgets('detail page shows average, max and asks for a birth year '
      'for zones', (tester) async {
    final app = TestApp();
    final sample = sampleActivity();
    app.activities.store[sample.id] = Activity(
      id: sample.id,
      type: sample.type,
      title: sample.title,
      startedAt: sample.startedAt,
      endedAt: sample.endedAt,
      movingTime: sample.movingTime,
      segments: sample.segments,
      heartRate: sampleHeartRate(),
    );
    await app.pump(tester);
    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('วิ่งตอนเช้า').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('อัตราการเต้นหัวใจ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('สูงสุด'), findsOneWidget);
    expect(find.textContaining('135', findRichText: true), findsOneWidget);
    expect(
      find.text('กรอกปีเกิดหรือ Max HR ในโปรไฟล์ เพื่อดูเวลาในแต่ละโซน'),
      findsOneWidget,
    );
  });

  testWidgets('the profile settings open the same sensor sheet', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();
    final row = find.text('เซนเซอร์ชีพจร / นาฬิกา');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'เชื่อมต่อ'));
    await tester.pumpAndSettle();
    expect(find.text('อุปกรณ์ใกล้เคียง'), findsOneWidget);

    app.heartRate.scanning!.add(const [
      HeartRateSensor(
        id: 'g',
        name: 'Forerunner 265',
        advertisesHeartRate: true,
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forerunner 265'));
    await tester.pumpAndSettle();
    app.heartRate
      ..emitStatus(SensorLink.connected)
      ..emitReading(66);
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('Forerunner 265 · 66 bpm'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'จัดการ'), findsOneWidget);
  });
}
