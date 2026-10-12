import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:prachaya_run/core/network/api_config.dart';
import 'package:prachaya_run/features/activity/domain/repositories/activity_photo_repository.dart';
import 'package:prachaya_run/features/activity/domain/services/uuid.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/sync/sync_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/pages/home_page.dart';
import 'package:prachaya_run/features/athlete/presentation/bloc/gear_cubit.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/presentation/debug_cubit.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:prachaya_run/features/training/presentation/bloc/training_cubit.dart';
import 'package:prachaya_run/main.dart' as app;

/// End to end on a simulator against the real rinning_API at
/// [apiBaseUrl]: a profile, shoe and plan made signed out, sign up, sample
/// data, a simulated run (linked to the shoe), a photo, a "second device"
/// editing plans through the API, sync, challenge — checked through the UI
/// and straight against the API.
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

  testWidgets('profile, shoe, plan, sign up, record, sync across devices', (
    tester,
  ) async {
    // Never leave a test account behind (e.g. on production), even when a
    // step fails: log in again and delete it. A 401 means it is gone.
    addTearDown(() async {
      final login = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (login.statusCode != 200) return;
      final token =
          (jsonDecode(login.body) as Map<String, Object?>)['accessToken'];
      final deleted = await http.delete(
        Uri.parse('$apiBaseUrl/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint('e2e cleanup: DELETE /me → ${deleted.statusCode}');
    });
    await app.main();
    await waitFor(tester, find.text('พร้อมออกไปวิ่งหรือยัง?'));
    final home = tester.element(find.byType(HomePage));

    Future<void> toTop() async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await wait(tester);
    }

    Future<void> scrollTo(Finder f) async {
      await tester.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await wait(tester);
    }

    Future<void> enterField(int index, String text) async {
      await tester.enterText(find.byType(TextField).at(index), text);
      await wait(tester, 200);
    }

    // --- Profile: start signed out (the avatar opens the profile) ---
    await tester.tap(find.byTooltip('บัญชี').first);
    await waitFor(tester, find.text('ข้อมูลผู้ใช้'));
    // Signed in from an earlier run? The bottom of the profile says so.
    await scrollTo(find.text('การตั้งค่า'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await wait(tester);
    final logout = find.text('ออกจากระบบบัญชีนักวิ่ง');
    if (logout.evaluate().isNotEmpty) {
      await tester.ensureVisible(logout);
      await tester.tap(logout);
      await waitFor(tester, find.text('ออกจากระบบ?'));
      await tester.tap(find.text('ออกจากระบบ').last);
      await waitFor(tester, find.text('เข้าสู่ระบบเพื่อซิงก์ข้ามเครื่อง'));
    }
    await toTop();

    // Body data through the edit sheet, signed out (device profile).
    await tester.tap(find.byTooltip('แก้ไขโปรไฟล์'));
    await waitFor(tester, find.text('แก้ไขข้อมูลผู้ใช้'));
    await enterField(0, 'E2E Runner');
    await enterField(1, '70');
    await enterField(2, '175');
    await enterField(3, '2540'); // พ.ศ. → 1997
    await enterField(4, '');
    await tester.tap(find.text('บันทึกโปรไฟล์'));
    await waitFor(tester, find.text('BMI 22.9 • สมส่วน'));

    // A shoe, signed out.
    await scrollTo(find.text('เพิ่มอุปกรณ์'));
    await tester.tap(find.text('เพิ่มอุปกรณ์'));
    await waitFor(tester, find.text('ชื่อรองเท้า'));
    await enterField(0, 'E2E Shoe');
    await enterField(3, '100');
    final addShoe = find.text('เพิ่มรองเท้า').last;
    await tester.ensureVisible(addShoe);
    await tester.tap(addShoe);
    await waitFor(tester, find.text('รองเท้าคู่หลัก'));
    await shot(tester, '01_profile_signed_out');

    // A planned session, signed out.
    final training = home.read<TrainingCubit>();
    final now = DateTime.now();
    final planId = uuidV4();
    await training.save(
      PlannedWorkout(
        id: planId,
        type: WorkoutType.tempo,
        title: 'E2E Tempo',
        location: 'สวนลุมพินี',
        scheduledAt: DateTime(now.year, now.month, now.day, 23, 59),
        distanceMeters: 7000,
        paceMinSecPerKm: 315,
        paceMaxSecPerKm: 330,
      ),
    );

    // --- Sign up through the UI: everything made signed out is claimed ---
    await toTop();
    await tester.tap(find.text('เข้าสู่ระบบเพื่อซิงก์'));
    await waitFor(tester, find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    await tester.tap(find.text('สมัครสมาชิก'));
    await wait(tester);
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.tap(find.text('สร้างบัญชี'));
    await waitFor(tester, find.text('ซิงก์ตอนนี้'));
    expect(find.text(email), findsOneWidget);
    await home.read<SyncCubit>().sync();
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
    expect(me['heightCm'], 175);
    expect(me['birthYear'], 1997);

    Future<List<Map<String, Object?>>> listAll(String path) async {
      final page = await api(
        'GET',
        '$path?updatedSince=1970-01-01T00:00:00.000Z&limit=500',
        token: token,
      );
      return (page['items']! as List).cast<Map<String, Object?>>();
    }

    final serverShoes = await listAll('/shoes');
    expect(serverShoes, hasLength(1));
    expect(serverShoes.single['name'], 'E2E Shoe');
    expect(serverShoes.single['primary'], isTrue);
    expect(serverShoes.single['startDistanceM'], 100000);
    final shoeId = serverShoes.single['id']! as String;
    final serverPlans = await listAll('/workouts');
    expect(serverPlans.single['id'], planId);
    expect(serverPlans.single['title'], 'E2E Tempo');

    // --- "Second device": edits plans straight through the API ---
    final otherId = uuidV4();
    final later = DateTime.now().toUtc().add(const Duration(minutes: 1));
    await api(
      'PUT',
      '/workouts/$otherId',
      token: token,
      body: {
        'type': 'long',
        'title': 'Long from phone 2',
        'location': null,
        'scheduledAt': now
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
        'distanceM': 15000,
        'paceMinSecPerKm': 360,
        'paceMaxSecPerKm': 375,
        'completedActivityId': null,
        'updatedAt': later.toIso8601String(),
      },
    );
    await home.read<SyncCubit>().sync();
    await home.read<SyncCubit>().sync(); // a second run adds nothing
    await training.load();
    expect(training.state.workouts, hasLength(2));
    expect(training.state.workouts.map((w) => w.id).toSet(), {planId, otherId});

    // Its newer edit wins over the copy here.
    await api(
      'PUT',
      '/workouts/$otherId',
      token: token,
      body: {
        ...(await listAll('/workouts')).firstWhere((w) => w['id'] == otherId),
        'title': 'Long edited on phone 2',
        'updatedAt': later.add(const Duration(minutes: 1)).toIso8601String(),
      },
    );
    await home.read<SyncCubit>().sync();
    await training.load();
    expect(
      training.state.workouts.firstWhere((w) => w.id == otherId).title,
      'Long edited on phone 2',
    );

    await tester.tap(find.byTooltip('กลับ').first);
    await waitFor(tester, find.text('ข้อมูลผู้ใช้'));
    await shot(tester, '03_profile_signed_in');
    await toTop();
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
    // The run counts toward the primary shoe, here and on the server.
    expect(serverRun['shoeId'], shoeId);
    final gear = home.read<GearCubit>();
    await gear.load();
    expect(
      gear.state.usage.single.usedMeters,
      closeTo(100000 + recorded.distanceMeters, 1),
    );
    // …and ticks off today's planned session.
    final plan = (await listAll(
      '/workouts',
    )).firstWhere((w) => w['id'] == planId);
    expect(plan['completedActivityId'], recorded.id);

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

    // --- Training plan screens ---
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await wait(tester);
    await scrollTo(find.text('ดูตาราง'));
    await tester.tap(find.text('ดูตาราง'));
    await waitFor(tester, find.text('กำหนดการวิ่ง & ตารางซ้อม'));
    await shot(tester, '10_schedule');
    await tester.tap(find.text('เพิ่มตาราง'));
    await waitFor(tester, find.text('สร้างตารางซ้อมใหม่'));
    await shot(tester, '11_new_workout');
    await tester.tap(find.byTooltip('ปิด'));
    await wait(tester, 800);

    // A delete here reaches the server as a tombstone; nothing duplicated.
    await training.delete(otherId);
    await home.read<SyncCubit>().sync();
    final plans = await listAll('/workouts');
    expect(plans, hasLength(2));
    expect(plans.firstWhere((w) => w['id'] == otherId)['deletedAt'], isNotNull);
    expect(plans.firstWhere((w) => w['id'] == planId)['deletedAt'], isNull);
    await tester.tap(find.byTooltip('กลับ').first);
    // Home is still scrolled down to the training card.
    await waitFor(tester, find.text('ดูตาราง'));

    // --- History ---
    await tester.tap(find.byTooltip('ประวัติ'));
    await waitFor(tester, find.text('ประวัติกิจกรรม'));
    await shot(tester, '09_history');

    // --- Delete the account (cleans the server; App Store requirement) ---
    await tester.tap(find.byTooltip('หน้าหลัก'));
    await wait(tester);
    await toTop();
    await tester.tap(find.byTooltip('บัญชี').first);
    await waitFor(tester, find.text('ข้อมูลผู้ใช้'));
    await scrollTo(find.text('บัญชีและซิงก์ข้อมูล'));
    await tester.tap(find.text('บัญชีและซิงก์ข้อมูล'));
    await waitFor(tester, find.text('ลบบัญชี'));
    await tester.ensureVisible(find.text('ลบบัญชี'));
    await wait(tester, 800);
    await shot(tester, '12_account_before_delete');
    await tester.tap(find.text('ลบบัญชี'));
    await waitFor(tester, find.text('ลบบัญชีถาวร?'));
    await tester.tap(find.text('ลบบัญชี').last);
    await waitFor(tester, find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    // The account's shoes and plans went with it.
    final again = await api(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password},
    );
    final fresh = again['accessToken']! as String;
    final shoesAfter = await api(
      'GET',
      '/shoes?updatedSince=1970-01-01T00:00:00.000Z',
      token: fresh,
    );
    expect(shoesAfter['items'], isEmpty);
    await api('DELETE', '/me', token: fresh);
    final gone = await http.post(
      Uri.parse('$apiBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    expect(gone.statusCode, 401);
  });
}
