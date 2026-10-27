import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/auth/domain/entities/auth_user.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWidgets('signed in, the profile offers to link Polar in the browser', (
    tester,
  ) async {
    final app = TestApp();
    app.auth.user = const AuthUser(id: 'u1', email: 'a@b.co');
    await app.pump(tester);
    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('บัญชีนาฬิกา'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Polar'), findsOneWidget);
    expect(find.text('ยังไม่ได้เชื่อมต่อ'), findsOneWidget);
    // The one in the Polar row (the sensor row has its own เชื่อมต่อ).
    final link = find.descendant(
      of: find
          .ancestor(of: find.text('Polar'), matching: find.byType(Row))
          .first,
      matching: find.widgetWithText(TextButton, 'เชื่อมต่อ'),
    );
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(app.browser.opened.single.host, 'flow.polar.com');
  });

  testWidgets('signed out, no account card', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.byTooltip('บัญชี').first);
    await tester.pumpAndSettle();
    expect(find.text('บัญชีนาฬิกา'), findsNothing);
  });
}
