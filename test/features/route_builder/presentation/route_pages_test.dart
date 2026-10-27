import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/route_builder/domain/repositories/route_snapper.dart';
import 'package:prachaya_run/features/training/presentation/pages/schedule_page.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    // The map's tile cache asks for a cache directory.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.createTempSync('tiles').path,
        );
  });

  Future<void> openRoutes(WidgetTester tester, TestApp app) async {
    await app.pump(tester);
    final navigator = Navigator.of(tester.element(find.byType(Scaffold).first));
    navigator.push(SchedulePage.route());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('เส้นทางวิ่งจากรูปวาด'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear of the bottom edge fade.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เส้นทางวิ่งจากรูปวาด'));
    await tester.pumpAndSettle();
    expect(find.text('วาดรูป แล้ววิ่งตามรูป'), findsOneWidget);
  }

  /// Draws an L in the upper half of the map.
  Future<void> drawL(WidgetTester tester) async {
    final area = tester.getRect(find.bySemanticsLabel('พื้นที่วาดเส้นทาง'));
    final gesture = await tester.startGesture(
      area.topLeft + Offset(area.width * 0.25, area.height * 0.15),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('draw a shape, find the route and save it', (tester) async {
    final app = TestApp();
    await openRoutes(tester, app);
    expect(find.textContaining('ยังไม่มีเส้นทาง'), findsOneWidget);

    await tester.tap(find.text('วาดเส้นทาง'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ลากนิ้วบนแผนที่'), findsOneWidget);

    await drawL(tester);
    expect(find.text('ยังไม่ได้หาเส้นทาง'), findsOneWidget);

    await tester.tap(find.text('หาเส้นทาง'));
    await tester.pumpAndSettle();
    expect(app.snapper.calls, hasLength(1));
    expect(find.text('เหมือนรูป 100%'), findsOneWidget);

    await tester.tap(find.text('บันทึกเส้นทาง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ตัว L');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(app.routes.store.values.single.name, 'ตัว L');
    expect(app.routes.store.values.single.closed, isTrue);
    expect(find.text('วาดรูป แล้ววิ่งตามรูป'), findsOneWidget);
    expect(find.text('ตัว L'), findsOneWidget);
    expect(find.text('เหมือนรูป 100%'), findsOneWidget);
  });

  testWidgets('signed out: says why, and saves the drawing alone', (
    tester,
  ) async {
    final app = TestApp()..snapper.error = RouteSnapError.signedOut;
    await openRoutes(tester, app);
    await tester.tap(find.text('วาดเส้นทาง'));
    await tester.pumpAndSettle();
    await drawL(tester);

    await tester.tap(find.text('หาเส้นทาง'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('เข้าสู่ระบบเพื่อให้ระบบหาเส้นทาง'),
      findsOneWidget,
    );

    await tester.tap(find.text('บันทึกรูปวาด'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ร่าง');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(app.routes.store.values.single.isSnapped, isFalse);
    expect(find.text('ยังไม่ได้หาเส้นทาง'), findsOneWidget);
  });

  testWidgets('open a saved route and delete it', (tester) async {
    final app = TestApp();
    await openRoutes(tester, app);
    await tester.tap(find.text('วาดเส้นทาง'));
    await tester.pumpAndSettle();
    await drawL(tester);
    await tester.tap(find.text('หาเส้นทาง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกเส้นทาง'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ลบฉัน');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ลบฉัน'));
    await tester.pumpAndSettle();
    expect(find.text('บันทึกเส้นทาง'), findsOneWidget); // reopened snapped
    await tester.tap(find.byTooltip('ลบเส้นทาง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    expect(app.routes.store, isEmpty);
    expect(find.textContaining('ยังไม่มีเส้นทาง'), findsOneWidget);
  });
}
