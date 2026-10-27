import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/imported_workout.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('turn on watch import in the profile; the dashboard says what '
      'came in and the detail shows a run without a route', (tester) async {
    final app = TestApp();
    final now = DateTime.now();
    app.health.stored.add(
      ImportedWorkout(
        source: 'health-connect',
        externalId: 'w1',
        kind: WorkoutKind.run,
        start: now.subtract(const Duration(hours: 3)),
        end: now.subtract(const Duration(hours: 2, minutes: 30)),
        distanceMeters: 6200,
        app: 'Samsung Health',
        device: 'Galaxy Watch7',
      ),
    );
    await app.pump(tester);

    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();
    final row = find.text('นำเข้ากิจกรรมจากนาฬิกา');
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final toggle = find.descendant(
      of: find.ancestor(of: row, matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ย้อนหลัง 30 วัน'));
    await tester.pumpAndSettle();
    expect(app.health.asked, isTrue);
    expect(app.activities.store, hasLength(1));
    expect(find.text('นำเข้าตอนนี้'), findsOneWidget);
    expect(find.textContaining('1 กิจกรรม'), findsOneWidget);

    // The top bar scrolled away with the list.
    Navigator.of(tester.element(find.text('นำเข้าตอนนี้'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('นำเข้ากิจกรรมใหม่จากนาฬิกา 1 รายการ'), findsOneWidget);
    expect(find.text('ไม่มีเส้นทาง GPS'), findsOneWidget);

    await tester.tap(find.text('นำเข้ากิจกรรมใหม่จากนาฬิกา 1 รายการ'));
    await tester.pumpAndSettle();
    expect(find.text('นำเข้ากิจกรรมใหม่จากนาฬิกา 1 รายการ'), findsNothing);
    expect(find.text('Samsung Health'), findsOneWidget); // history tag

    await tester.tap(find.text('Samsung Health'));
    await tester.pumpAndSettle();
    expect(find.text('ระยะทางตามที่ Galaxy Watch7 บันทึก'), findsOneWidget);
    expect(find.text('6.20 km'), findsOneWidget);
  });
}
