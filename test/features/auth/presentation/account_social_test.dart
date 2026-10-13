import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/services/best_efforts.dart';
import 'package:prachaya_run/features/auth/domain/entities/guest_data_summary.dart';
import 'package:prachaya_run/features/auth/domain/repositories/auth_repository.dart';
import 'package:prachaya_run/features/auth/presentation/pages/account_page.dart';
import 'package:prachaya_run/features/auth/presentation/widgets/guest_link_sheet.dart';

import '../../../helpers/pump_app.dart';

void main() {
  const guestData = GuestDataSummary(
    activityCount: 14,
    distanceMeters: 84200,
    movingTime: Duration(hours: 8, minutes: 42),
    bests: PersonalBests(
      fiveK: Duration(minutes: 24, seconds: 18),
      tenK: Duration(minutes: 53, seconds: 2),
    ),
    shoeCount: 1,
  );

  Future<TestApp> openAccount(
    WidgetTester tester, {
    GuestDataSummary data = guestData,
  }) async {
    final app = TestApp()
      ..auth.providers = {SocialProvider.apple, SocialProvider.google}
      ..guest.data = data;
    await app.pump(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(AccountPage.route());
    await tester.pumpAndSettle();
    return app;
  }

  Future<void> tapApple(WidgetTester tester) async {
    final apple = find.byKey(const Key('social-apple'));
    await tester.scrollUntilVisible(
      apple,
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(apple);
    await tester.pumpAndSettle();
    await tester.tap(apple, warnIfMissed: true);
    await tester.pumpAndSettle();
  }

  /// Scrolls the 07.1 sheet to [target] and taps it.
  Future<void> tapInSheet(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(GuestLinkSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder inSheet(String text) => find.descendant(
    of: find.byType(GuestLinkSheet),
    matching: find.text(text),
  );

  testWidgets('07: Apple and Google buttons under the form', (tester) async {
    await openAccount(tester);
    expect(find.text('หรือเข้าสู่ระบบด้วย (SOCIAL SIGN-IN)'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Apple'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
  });

  testWidgets('no providers: no social section', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(AccountPage.route());
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบด้วย Apple'), findsNothing);
  });

  testWidgets('07.1: after Apple sign-in, merge the device data', (
    tester,
  ) async {
    final app = await openAccount(tester);
    await tapApple(tester);

    expect(app.auth.socialSignIns, [SocialProvider.apple]);
    expect(find.text('ผูกและโอนย้ายข้อมูลเข้าบัญชี'), findsOneWidget);
    expect(inSheet('Apple ID'), findsOneWidget);
    expect(inSheet('apple@example.com'), findsOneWidget);
    expect(inSheet('14'), findsOneWidget);
    expect(inSheet('84.2'), findsOneWidget);
    expect(inSheet('8:42'), findsOneWidget);
    expect(inSheet('5K 24:18'), findsOneWidget);
    expect(inSheet('10K 53:02'), findsOneWidget);
    expect(inSheet('รองเท้า 1'), findsOneWidget);

    await tapInSheet(tester, find.byKey(const Key('guest-merge')));
    expect(app.guest.calls, ['merge:u1']);
    expect(find.text('ผูกและโอนย้ายข้อมูลเข้าบัญชี'), findsNothing);
  });

  testWidgets('07.1: keep on this device', (tester) async {
    final app = await openAccount(tester);
    await tapApple(tester);
    await tapInSheet(tester, find.byKey(const Key('guest-keep')));
    expect(app.guest.calls, ['keep']);
    expect(app.auth.user, isNotNull);
  });

  testWidgets('07.1: cancel signs out again', (tester) async {
    final app = await openAccount(tester);
    await tapApple(tester);
    await tapInSheet(tester, find.text('ยกเลิก / ออกจากระบบ'));
    expect(app.auth.user, isNull);
    expect(app.guest.calls, ['restore']);
    expect(find.text('ผูกและโอนย้ายข้อมูลเข้าบัญชี'), findsNothing);
  });

  testWidgets('nothing recorded signed out: no question', (tester) async {
    final app = await openAccount(tester, data: GuestDataSummary.empty);
    await tapApple(tester);
    expect(app.auth.user, isNotNull);
    expect(find.text('ผูกและโอนย้ายข้อมูลเข้าบัญชี'), findsNothing);
  });
}
