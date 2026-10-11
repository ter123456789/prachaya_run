import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:prachaya_run/core/network/api_config.dart';
import 'package:prachaya_run/features/activity/domain/repositories/activity_photo_repository.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/sync/sync_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/pages/home_page.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/presentation/debug_cubit.dart';
import 'package:prachaya_run/main.dart' as app;

/// End to end on a simulator against the real rinning_API at
/// [apiBaseUrl]: sign up, profile, sample data, a simulated run, a photo,
/// sync, challenge — checked through the UI and straight against the API.
///
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/app_e2e_test.dart -d SIMULATOR_ID
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final email = 'e2e+${DateTime.now().millisecondsSinceEpoch}@prachaya.run';
  const password = 'password123';

  Future<void> wait(WidgetTester tester, [int ms = 600]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pump();
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure('Timed out waiting for $finder');
      }
      await wait(tester, 200);
    }
    await wait(tester, 500);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await wait(tester, 900); // let entrance animations finish
    await binding.takeScreenshot(name);
  }

  Future<Map<String, Object?>> api(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send());
    expect(
      response.statusCode,
      lessThan(300),
      reason: '$path ${response.body}',
    );
    return response.body.isEmpty
        ? const {}
        : jsonDecode(response.body) as Map<String, Object?>;
  }

  Future<List<int>> pngBytes() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFFD4F36B),
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  testWidgets('sign up, record, sync, photo, challenge', (tester) async {
    await app.main();
    await waitFor(tester, find.text('พร้อมออกไปวิ่งหรือยัง?'));
    final home = tester.element(find.byType(HomePage));

    // --- Account: start signed out, then sign up through the UI ---
    await tester.tap(find.byTooltip('บัญชี').first);
    await waitFor(tester, find.text('บัญชี'));
    if (find.text('ออกจากระบบ').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('ออกจากระบบ'));
      await tester.tap(find.text('ออกจากระบบ'));
      await waitFor(tester, find.text('ออกจากระบบ?'));
      await tester.tap(find.text('ออกจากระบบ').last);
      await waitFor(tester, find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    }
    await shot(tester, '01_account_signed_out');

    await tester.tap(find.text('สมัครสมาชิก'));
    await wait(tester);
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('สร้างบัญชี'));
    await waitFor(tester, find.text('ซิงก์ตอนนี้'));
    expect(find.text(email), findsOneWidget);

    // Profile (PATCH /me) through the UI.
    await tester.enterText(find.byType(TextField).at(0), 'E2E Runner');
    await tester.enterText(find.byType(TextField).at(1), '70');
    await tester.ensureVisible(find.text('บันทึกโปรไฟล์'));
    await tester.tap(find.text('บันทึกโปรไฟล์'));
    await waitFor(tester, find.text('บันทึกโปรไฟล์แล้ว'));
    await shot(tester, '02_account_signed_in');

    final login = await api(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final token = login['accessToken']! as String;
    final me = await api('GET', '/me', token: token);
    expect(me['displayName'], 'E2E Runner');
    expect(me['weightKg'], 70);

    // The top bar scrolled away while saving; bring it back first.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await wait(tester);
    await tester.tap(find.byTooltip('กลับ').first);
    await waitFor(tester, find.text('พร้อมออกไปวิ่งหรือยัง?'));

    // --- Sample data → sync → on the server ---
    final debug = home.read<DebugCubit>();
    final sync = home.read<SyncCubit>();
    await debug.seed();
    await sync.sync();
    var feed = await api(
      'GET',
      '/activities?updatedSince=1970-01-01T00:00:00.000Z&limit=500',
      token: token,
    );
    expect((feed['items']! as List).length, 10);

    // --- A simulated run at ×60 through the recorder UI ---
    debug.setGps(
      const GpsSimulation(enabled: true, speed: 60, route: SimRoute.lumpini),
    );
    await tester.tap(find.byTooltip('เริ่มบันทึก'));
    await waitFor(tester, find.byTooltip('เริ่ม'));
    await shot(tester, '03_record_idle');
    await tester.tap(find.byTooltip('เริ่ม'));
    await waitFor(tester, find.text('REC'));
    for (var i = 0; i < 40; i++) {
      await wait(tester, 500); // 20 s real ≈ 20 min simulated
    }
    await shot(tester, '04_record_live');
    await tester.tap(find.byTooltip('จบและบันทึก'));
    await waitFor(
      tester,
      find.text('ใส่เส้นทางและสถิติลงรูปภาพ'),
      timeout: const Duration(seconds: 30),
    );
    debug.setGps(const GpsSimulation());
    await shot(tester, '05_detail');

    // --- Photo on the recorded activity → uploaded ---
    final dashboard = home.read<DashboardCubit>();
    await dashboard.load();
    final recorded = dashboard.state.latest!;
    await home.read<ActivityPhotoRepository>().add(
      recorded.id,
      await pngBytes(),
      takenAt: DateTime.now(),
    );
    await sync.sync();
    final photos = await api(
      'GET',
      '/activities/${recorded.id}/photos',
      token: token,
    );
    final items = (photos['items']! as List).cast<Map<String, Object?>>();
    expect(items, hasLength(1));
    final file = await http.get(Uri.parse(items.single['url']! as String));
    expect(file.statusCode, 200);
    expect(file.bodyBytes.take(4), [0x89, 0x50, 0x4E, 0x47]);

    feed = await api(
      'GET',
      '/activities?updatedSince=1970-01-01T00:00:00.000Z&limit=500',
      token: token,
    );
    final serverItems = (feed['items']! as List).cast<Map<String, Object?>>();
    final serverRun = serverItems.firstWhere((a) => a['id'] == recorded.id);
    expect(serverRun['photoCount'], 1);
    // Server totals match the app's (same formulas both sides).
    expect(
      (serverRun['distanceM']! as num).toDouble(),
      closeTo(recorded.distanceMeters, 1),
    );

    // --- Share studio ---
    await tester.tap(find.text('ใส่เส้นทางและสถิติลงรูปภาพ'));
    await waitFor(tester, find.text('สตูดิโอแชร์รูป'));
    await shot(tester, '06_share_studio');
    await tester.tap(find.byTooltip('กลับ').first);
    await wait(tester, 800);
    await tester.tap(find.byTooltip('กลับ').first);
    await waitFor(tester, find.text('พร้อมออกไปวิ่งหรือยัง?'));

    // --- Challenge: from the server, shown on the dashboard ---
    final challenge = await api('GET', '/challenges/current', token: token);
    expect(challenge['goalM'], isA<num>());
    await dashboard.load();
    await wait(tester, 1500);
    await shot(tester, '07_home');
    await tester.scrollUntilVisible(
      find.text(challenge['title']! as String),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(tester, '08_home_challenge');

    // --- History ---
    await tester.tap(find.byTooltip('ประวัติ'));
    await waitFor(tester, find.text('ประวัติกิจกรรม'));
    await shot(tester, '09_history');

    // --- Delete the account (cleans the server; App Store requirement) ---
    await tester.tap(find.byTooltip('บัญชี').last);
    await waitFor(tester, find.text('ลบบัญชี'));
    await tester.ensureVisible(find.text('ลบบัญชี'));
    await wait(tester, 800);
    await shot(tester, '10_account_before_delete');
    await tester.tap(find.text('ลบบัญชี'));
    await waitFor(tester, find.text('ลบบัญชีถาวร?'));
    await tester.tap(find.text('ลบบัญชี').last);
    await waitFor(tester, find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    final gone = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    expect(gone.statusCode, 401);
  });
}
