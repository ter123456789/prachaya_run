import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/features/athlete/domain/services/heart_rate_zones.dart';
import 'package:prachaya_run/features/activity/presentation/pages/activity_detail_page.dart';
import 'package:prachaya_run/features/athlete/presentation/pages/profile_page.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลผู้ใช้'), findsOneWidget);
  }

  /// The top bar scrolls away with the list; bring it back, then go back.
  Future<void> back(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('กลับ').first);
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    Finder f, {
    Type page = ProfilePage,
  }) async {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .descendant(of: find.byType(page), matching: find.byType(Scrollable))
          .first,
    );
    // Built may still mean partly below the edge: bring it fully in view.
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  testWidgets('empty profile works without an account', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await openProfile(tester);

    // 08 guest: Local Only and an invitation, nothing locked.
    expect(find.text('โหมดผู้เยี่ยมชม (Guest Mode)'), findsOneWidget);
    expect(find.text('LOCAL ONLY'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบเพื่อสำรองและซิงก์ข้อมูล'), findsOneWidget);
    expect(find.text('ยังไม่มีกิจกรรม'), findsOneWidget);
    // No design sample values or features without a data source.
    expect(find.text('64.5'), findsNothing);
    expect(find.text('Resting HR'), findsNothing);
    expect(find.textContaining('VO2 Max'), findsNothing);
    expect(find.textContaining('Strava'), findsNothing);
    expect(find.textContaining('+18.4%'), findsNothing);
    await scrollTo(tester, find.text('กรอกข้อมูลร่างกาย'));
    await scrollTo(tester, find.textContaining('ยังไม่มีรองเท้า'));

    // "Why an account?" jumps to the benefits.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทำไมต้องมีบัญชี? (ดูสิทธิประโยชน์)'));
    await tester.pumpAndSettle();
    expect(find.text('ซิงก์ข้อมูลข้ามเครื่อง'), findsOneWidget);
    expect(find.text('สิทธิประโยชน์เมื่อมีบัญชี'), findsOneWidget);
  });

  testWidgets('editing the profile updates BMI and zones at once', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);
    await openProfile(tester);

    await tester.tap(find.byTooltip('แก้ไขโปรไฟล์'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ปราชญา');
    await tester.enterText(fields.at(1), '64.5');
    await tester.enterText(fields.at(2), '175');
    await tester.enterText(fields.at(3), '2545'); // พ.ศ. → 2002
    await tester.pumpAndSettle();
    final age = DateTime.now().year - 2002;
    final max = tanakaMaxHr(age);
    expect(find.textContaining('ใช้ $max bpm'), findsOneWidget);
    await tester.tap(find.text('บันทึกโปรไฟล์'));
    await tester.pumpAndSettle();

    expect(app.profile.profile.birthYear, 2002);
    expect(find.textContaining('ปราชญา'), findsOneWidget);
    await scrollTo(tester, find.text('BMI 21.1 • สมส่วน'));
    expect(find.text('$max'), findsOneWidget);
    expect(find.text('เกณฑ์ Tanaka Method'), findsOneWidget);
    final z1 = heartRateZones(max).first;
    await scrollTo(tester, find.text('${z1.lowBpm} - ${z1.highBpm} bpm'));

    // A Max HR of their own replaces the estimate everywhere.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('แก้ไขโปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(4), '200');
    await tester.tap(find.text('บันทึกโปรไฟล์'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('100 - 119 bpm'));
    expect(find.text('≥180 bpm'), findsOneWidget);
  });

  testWidgets('out-of-range values are flagged in the sheet', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await openProfile(tester);
    await tester.tap(find.byTooltip('แก้ไขโปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(4), '260');
    await tester.tap(find.text('บันทึกโปรไฟล์'));
    await tester.pumpAndSettle();
    expect(find.text('100–230 bpm'), findsOneWidget);
    expect(app.profile.profile.maxHrBpm, isNull);
  });

  testWidgets('a shoe counts the runs linked to it; units switch app-wide', (
    tester,
  ) async {
    final app = TestApp();
    final run = sampleActivity();
    app.activities.store[run.id] = run;
    await app.pump(tester);
    await openProfile(tester);

    await scrollTo(tester, find.text('เพิ่มอุปกรณ์'));
    await tester.tap(find.text('เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pegasus 41');
    final add = find.text('เพิ่มรองเท้า').last; // the sheet's button
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final shoe = app.shoes.store.values.single;
    expect(shoe.primary, isTrue); // the first shoe
    expect(find.text('Pegasus 41'), findsOneWidget);
    expect(find.text('รองเท้าคู่หลัก'), findsOneWidget);
    expect(find.text('0.0 กม.'), findsOneWidget);

    // Link the existing run from its detail screen.
    await back(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ประวัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('วิ่งตอนเช้า'));
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.text('รองเท้าที่ใช้'),
      page: ActivityDetailPage,
    );
    await tester.tap(find.text('รองเท้าที่ใช้'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pegasus 41').last);
    await tester.pumpAndSettle();
    expect(app.activities.store[run.id]!.shoeId, shoe.id);
    await back(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('หน้าหลัก'));
    await tester.pumpAndSettle();

    await openProfile(tester);
    final km = (run.distanceMeters / 1000).toStringAsFixed(1);
    await scrollTo(tester, find.text('$km กม.'));

    // Switch to miles.
    await scrollTo(tester, find.text('ไมล์'));
    await tester.tap(find.text('ไมล์'));
    await tester.pumpAndSettle();
    expect(app.settings.unit, DistanceUnit.mi);
    final mi = (run.distanceMeters / 1609.344).toStringAsFixed(1);
    // The shoe card is above the settings: start again from the top.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('$mi ไมล์'));
    await back(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('ไมล์', findRichText: true), findsWidgets);
  });

  testWidgets('all-time stats come from the activities', (tester) async {
    final app = TestApp();
    final run = sampleActivity();
    app.activities.store[run.id] = run;
    await app.pump(tester);
    await openProfile(tester);
    await scrollTo(tester, find.text('สถิติตลอดกาล (All-Time)'));
    expect(find.text('2569 - ปัจจุบัน'), findsOneWidget);
    expect(find.text('ครั้ง (วิ่ง 100%)'), findsOneWidget);
    expect(
      find.text((run.distanceMeters / 1000).toStringAsFixed(1)),
      findsWidgets,
    );
  });

  testWidgets('reminder and voice settings are device settings', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);
    await openProfile(tester);

    Finder switchOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

    await scrollTo(tester, find.text('แจ้งอากาศตอนเช้า 06:00 น.'));
    await tester.tap(switchOf('แจ้งอากาศตอนเช้า 06:00 น.'));
    await tester.pumpAndSettle();
    expect(app.reminderSettings.settings.morningWeather, isTrue);
    expect(app.reminders.permissionRequests, greaterThan(0));

    await scrollTo(tester, find.text('1 ชม.'));
    await tester.tap(find.text('1 ชม.'));
    await tester.pumpAndSettle();
    expect(app.reminderSettings.settings.workoutLeadMinutes, 60);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(switchOf('เสียงบอกเพซ (Audio Cues)'));
    await tester.pumpAndSettle();
    await tester.tap(switchOf('เสียงบอกเพซ (Audio Cues)'));
    await tester.pumpAndSettle();
    expect(app.reminderSettings.settings.audioCues, isFalse);

    // Denied in the OS: the card says where to turn it on.
    app.reminders.allow = false;
    await tester.ensureVisible(switchOf('แจ้งเมื่อบรรลุเป้ารายสัปดาห์'));
    await tester.pumpAndSettle();
    await tester.tap(switchOf('แจ้งเมื่อบรรลุเป้ารายสัปดาห์'));
    await tester.pumpAndSettle();
    await tester.tap(switchOf('แจ้งเมื่อบรรลุเป้ารายสัปดาห์'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.textContaining('การแจ้งเตือนถูกปิดอยู่'));
  });
}
