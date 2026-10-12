import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  Future<void> openSchedule(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('ตารางซ้อม'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ดูตาราง'));
    await tester.pumpAndSettle();
    expect(find.text('กำหนดการวิ่ง & ตารางซ้อม'), findsOneWidget);
  }

  /// Scrolls the page to a rich-text line, then scrolls back to the top.
  Future<void> seeRich(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text, findRichText: true),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
  }

  /// The sheet's own list (text fields have scrollables too).
  final sheetList = find
      .descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      )
      .first;

  /// The sheet's list builds lazily: scroll it until [f] is built.
  Future<void> inSheet(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: sheetList);
    await tester.pumpAndSettle();
  }

  Future<void> tapInSheet(WidgetTester tester, Finder f) async {
    await inSheet(tester, f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('plan, edit and delete a session (works signed out)', (
    tester,
  ) async {
    final app = TestApp();
    await app.pump(tester);
    expect(find.text('วางแผนการซ้อมสัปดาห์นี้'), findsNothing); // below fold
    await openSchedule(tester);

    expect(find.text('ยังไม่มีแผนสำหรับวันนี้'), findsOneWidget);
    await seeRich(tester, 'ความถี่สัปดาห์นี้: 0 / 0 ครั้ง');
    // No design sample data.
    expect(find.text('Half-Marathon Sub 2 Plan'), findsNothing);

    await tester.tap(find.text('วางแผนซ้อม'));
    await tester.pumpAndSettle();
    expect(find.text('สร้างตารางซ้อมใหม่'), findsOneWidget);
    // Tempo by default: 7 km in three phases.
    await inSheet(tester, find.text('3 ช่วงต่อเนื่อง'));
    expect(find.text('7.00'), findsOneWidget);
    expect(find.text("5'15\"-5'30\""), findsOneWidget);
    expect(find.textContaining('~37:38', findRichText: true), findsOneWidget);

    await tester.drag(sheetList, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Easy Run'));
    await tester.pumpAndSettle();
    await inSheet(tester, find.text('1 ช่วงต่อเนื่อง'));
    await tapInSheet(tester, find.byTooltip('เพิ่มระยะทาง'));
    expect(find.text('5.50'), findsOneWidget);
    await tester.drag(sheetList, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'สวนเบญจกิติ');
    await tester.tap(find.text('บันทึกและเพิ่มลงตาราง'));
    await tester.pumpAndSettle();

    final saved = app.workouts.store.values.single;
    expect(saved.type, WorkoutType.easy);
    expect(saved.distanceMeters, 5500);
    expect(saved.location, 'สวนเบญจกิติ');
    expect(find.text('Easy Run วิ่งสบายฟื้นฟู'), findsOneWidget);
    expect(find.text('สวนเบญจกิติ'), findsOneWidget);
    await seeRich(tester, 'ความถี่สัปดาห์นี้: 0 / 1 ครั้ง');
    expect(find.text('เริ่มวิ่งตามแผนนี้เลย'), findsOneWidget);

    // Edit: tap the card.
    await tester.tap(find.text('Easy Run วิ่งสบายฟื้นฟู'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขตารางซ้อม'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Easy เช้าวันหยุด');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(app.workouts.store.values.single.title, 'Easy เช้าวันหยุด');
    expect(find.text('Easy เช้าวันหยุด'), findsOneWidget);

    // Delete.
    await tester.tap(find.text('Easy เช้าวันหยุด'));
    await tester.pumpAndSettle();
    await tapInSheet(tester, find.text('ลบตารางนี้'));
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(app.workouts.store, isEmpty);
    expect(find.text('ยังไม่มีแผนสำหรับวันนี้'), findsOneWidget);
  });

  testWidgets('a rest day and the upcoming list', (tester) async {
    final app = TestApp();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await app.workouts.save(
      PlannedWorkout(
        id: 'next',
        type: WorkoutType.long,
        title: 'Long Run วิ่งยาว',
        scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6),
        distanceMeters: 15000,
        paceMinSecPerKm: 360,
        paceMaxSecPerKm: 375,
      ),
    );
    await app.pump(tester);
    await openSchedule(tester);
    await tester.scrollUntilVisible(
      find.text('Long Run วิ่งยาว'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 เซสชัน'), findsOneWidget);
    expect(find.text("15 กม. • โซน 2-3 • เพซ 6'00\"-6'15\""), findsOneWidget);

    // Plan a rest day today.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มตาราง'));
    await tester.pumpAndSettle();
    expect(find.text('สร้างตารางซ้อมใหม่'), findsOneWidget);
    await tester.tap(find.text('Rest Day (วันพักผ่อนฟื้นฟู)'));
    await tester.pumpAndSettle();
    expect(find.text('โครงสร้างช่วงการซ้อม (WORKOUT PHASES)'), findsNothing);
    await tester.tap(find.text('บันทึกและเพิ่มลงตาราง'));
    await tester.pumpAndSettle();
    expect(app.workouts.store.values.where((w) => w.isRest), hasLength(1));
    expect(find.text('พัก'), findsOneWidget); // week strip
  });

  testWidgets('a run on the day ticks the session off', (tester) async {
    final app = TestApp();
    final run = sampleActivity();
    app.activities.store[run.id] = run;
    final now = DateTime.now();
    await app.workouts.save(
      PlannedWorkout(
        id: 'today',
        type: WorkoutType.tempo,
        title: 'Tempo วันนี้',
        scheduledAt: DateTime(now.year, now.month, now.day, 18, 30),
        distanceMeters: 7000,
        paceMinSecPerKm: 315,
        paceMaxSecPerKm: 330,
        completedActivityId: run.id,
      ),
    );
    await app.pump(tester);
    await openSchedule(tester);
    expect(find.text('ซ้อมสำเร็จแล้ว ดูกิจกรรม'), findsOneWidget);
    await seeRich(tester, 'ความถี่สัปดาห์นี้: 1 / 1 ครั้ง');
  });
}
