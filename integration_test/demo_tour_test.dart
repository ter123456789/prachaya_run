import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:prachaya_run/core/network/api_config.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/core/widgets/glass_card.dart';
import 'package:prachaya_run/features/activity/presentation/activity_refresh.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/sync/sync_cubit.dart';
import 'package:prachaya_run/features/activity/presentation/pages/home_page.dart';
import 'package:prachaya_run/features/athlete/presentation/bloc/units_cubit.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/profile_cubit.dart';
import 'package:prachaya_run/features/auth/presentation/widgets/guest_link_sheet.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';
import 'package:prachaya_run/features/debug/presentation/debug_cubit.dart';
import 'package:prachaya_run/features/photo_share/presentation/bloc/photo_overlay_cubit.dart';
import 'package:prachaya_run/features/reminders/presentation/bloc/reminders_cubit.dart';
import 'package:prachaya_run/main.dart' as app;

/// A slow, watchable walk through every screen, for a screen recording.
/// Prints DEMO_START / DEMO_END so a script can start and stop
/// `xcrun simctl io <id> recordVideo` around the tour. Not an assertion test:
/// cosmetic steps that fail are logged and skipped.
///
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/demo_tour_test.dart -d SIMULATOR_ID \
///   --dart-define=DEMO_PHOTO=/path/to/photo.jpg
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final email = 'demo+${DateTime.now().millisecondsSinceEpoch}@prachaya.run';
  const password = 'password123';
  const photoPath = String.fromEnvironment('DEMO_PHOTO');

  testWidgets('demo tour', timeout: const Timeout(Duration(minutes: 20)), (
    tester,
  ) async {
    // Never leave the demo account behind on the server.
    addTearDown(() async {
      final login = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (login.statusCode != 200) return;
      final token =
          (jsonDecode(login.body) as Map<String, Object?>)['accessToken'];
      await http.delete(
        Uri.parse('$apiBaseUrl/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
    });

    Future<void> wait([int ms = 600]) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    Future<void> waitFor(
      Finder finder, {
      Duration timeout = const Duration(seconds: 25),
    }) async {
      final end = DateTime.now().add(timeout);
      while (finder.evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) {
          throw TestFailure('Timed out waiting for $finder');
        }
        await wait(200);
      }
      await wait(500);
    }

    /// Runs a cosmetic step; a failure is logged, the tour goes on.
    Future<void> step(String name, Future<void> Function() body) async {
      debugPrint('DEMO step: $name');
      try {
        await body();
      } catch (e) {
        debugPrint('DEMO step "$name" skipped: $e');
      }
    }

    Finder scrollable() => find.byType(Scrollable).first;

    /// A visible, finger-speed scroll.
    Future<void> glide(double dy, {Finder? on, int ms = 1100}) async {
      await tester.timedDrag(
        on ?? scrollable(),
        Offset(0, dy),
        Duration(milliseconds: ms),
      );
      await wait(900);
    }

    Future<void> toTop() async {
      await tester.fling(scrollable(), const Offset(0, 3000), 4000);
      await wait(1000);
    }

    Future<void> scrollTo(Finder f, {Finder? on}) async {
      await tester.scrollUntilVisible(
        f,
        250,
        scrollable: on ?? scrollable(),
        duration: const Duration(milliseconds: 250),
      );
      await tester.ensureVisible(f);
      await wait(300);
      final y = tester.getCenter(f).dy;
      if (y > 300) {
        await tester.timedDrag(
          on ?? scrollable(),
          Offset(0, 220 - y),
          const Duration(milliseconds: 700),
        );
      }
      await wait(700);
    }

    Future<void> tap(Finder f, [int after = 900]) async {
      // Chips in a horizontal row may start off screen: bring them in.
      try {
        await tester.ensureVisible(f);
        await wait(250);
      } catch (_) {}
      await tester.tap(f);
      await wait(after);
    }

    Future<void> type(Finder field, String text) async {
      await tester.tap(field);
      await wait(250);
      // Letter by letter so the typing shows.
      for (var i = 1; i <= text.length; i++) {
        tester.testTextInput.enterText(text.substring(0, i));
        await wait(55);
      }
      await wait(250);
    }

    Future<void> back() async {
      // The back button scrolls away with some pages' lists.
      if (find.byTooltip('กลับ').evaluate().isEmpty) {
        await tester.fling(scrollable(), const Offset(0, 3000), 4000);
        await wait(1000);
      }
      await tap(find.byTooltip('กลับ').first, 1200);
    }

    // ---------------------------------------------------------------
    // Off camera: start from a clean, signed-out device.
    await app.main();
    await waitFor(find.text('พร้อมออกไปวิ่งหรือยัง?'));
    final home = tester.element(find.byType(HomePage));
    final reminders = home.read<RemindersCubit>();
    await reminders.load();
    // Turning plan reminders on would raise the OS permission prompt.
    await reminders.setWorkoutLead(null);
    if (home.read<AuthCubit>().state.user != null) {
      await home.read<AuthCubit>().logout();
      await wait(1500);
    }
    await home.read<UnitsCubit>().set(DistanceUnit.km);
    await home.read<DebugCubit>().clearLocal();
    await home.refreshActivities();
    home.read<ProfileCubit>().load();
    // The floating debug button goes to the top-right corner, over the
    // status bar, so it covers no buttons.
    await tester.drag(
      find.byIcon(Icons.bug_report_rounded),
      const Offset(400, -2000),
    );
    await wait(2000);

    debugPrint('DEMO_START');
    await wait(2500); // the recorder needs a moment to start

    // --- 1. Home, empty ----------------------------------------------
    await wait(2500);

    // --- 2. Sample activities (debug panel's seed) → home with data --
    await home.read<DebugCubit>().seed();
    await home.refreshActivities();
    await wait(2500);
    await step('home scroll', () async {
      for (var i = 0; i < 4; i++) {
        await glide(-380);
        await wait(700);
      }
      await toTop();
    });

    // --- 3. History, filters, activity detail ------------------------
    await tap(find.byTooltip('ประวัติ'), 1500);
    await waitFor(find.text('ประวัติกิจกรรม'));
    await wait(1200);
    await step('history filters', () async {
      await tap(find.text('ปั่นจักรยาน').first, 1400);
      await tap(find.text('เดินป่า').first, 1400);
      await tap(find.text('ทั้งหมด').first, 1400);
    });
    await step('history scroll', () async {
      await glide(-400);
      await glide(-400);
      await toTop();
    });
    await step('activity detail', () async {
      final card = find
          .ancestor(
            of: find.text('ระยะทาง').first,
            matching: find.byType(GlassCard),
          )
          .first;
      await scrollTo(card);
      await tap(card, 1500);
      await waitFor(find.text('รายละเอียดกิจกรรม'));
      await wait(2500); // the route draws itself
      for (var i = 0; i < 5; i++) {
        await glide(-420);
        await wait(600);
      }
      await toTop();
      await back();
    });
    await tap(find.byTooltip('หน้าหลัก'), 1200);

    // --- 4. Profile (guest): edit, shoe, HR zones, units, settings ---
    await tap(find.byTooltip('บัญชี').first, 1500);
    await waitFor(find.text('ข้อมูลผู้ใช้'));
    await wait(1500);
    await step('edit profile', () async {
      await tap(find.byTooltip('แก้ไขโปรไฟล์').first, 1200);
      await waitFor(find.text('แก้ไขข้อมูลผู้ใช้'));
      await type(find.byType(TextField).at(0), 'Prachaya');
      await type(find.byType(TextField).at(1), '64');
      await type(find.byType(TextField).at(2), '172');
      await type(find.byType(TextField).at(3), '2538');
      await wait(800);
      await tap(find.text('บันทึกโปรไฟล์'), 1500);
    });
    await step('profile scroll', () async {
      await glide(-380);
      await glide(-380);
    });
    await step('add shoe', () async {
      await scrollTo(find.text('เพิ่มอุปกรณ์'));
      await tap(find.text('เพิ่มอุปกรณ์'), 1200);
      await waitFor(find.text('ชื่อรองเท้า'));
      await type(find.byType(TextField).at(0), 'Nike Pegasus 41');
      await type(find.byType(TextField).at(1), 'Daily Trainer');
      await type(find.byType(TextField).at(3), '120');
      final add = find.text('เพิ่มรองเท้า').last;
      await tester.ensureVisible(add);
      await wait(500);
      await tap(add, 1500);
      await waitFor(find.text('รองเท้าคู่หลัก'));
      await wait(1000);
    });
    await step('units km → mi → km', () async {
      await scrollTo(find.text('หน่วยวัดระยะทาง'));
      await wait(800);
      await tap(find.text('ไมล์').last, 1800);
      await glide(300);
      await wait(1200);
      await scrollTo(find.text('หน่วยวัดระยะทาง'));
      await tap(find.text('กม.').last, 1500);
    });
    await step('settings + bottom', () async {
      await glide(-400);
      await glide(-400);
      await wait(1000);
      await toTop();
    });
    await back();

    // --- 5. Training schedule + new workout --------------------------
    await step('schedule', () async {
      await scrollTo(find.text('ดูตาราง'));
      await tap(find.text('ดูตาราง'), 1500);
      await waitFor(find.text('ตารางซ้อม'));
      await wait(1500);
      await tap(find.text('เพิ่มตาราง'), 1500);
      await waitFor(find.text('สร้างตารางซ้อมใหม่'));
      await wait(1000);
      await tap(find.text('Tempo Run'), 1000);
      await tap(find.text('Interval'), 1000);
      await tap(find.text('Tempo Run'), 1000);
      await type(
        find.widgetWithText(TextField, 'สถานที่วิ่ง (ไม่บังคับ)'),
        'สวนลุมพินี',
      );
      final sheet = find
          .ancestor(
            of: find.text('สร้างตารางซ้อมใหม่'),
            matching: find.byType(Scaffold),
          )
          .first;
      final sheetScroll = find
          .descendant(
            of: find.byType(BottomSheet).evaluate().isEmpty
                ? sheet
                : find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      final plus = find.byTooltip('เพิ่มระยะทาง');
      await scrollTo(plus, on: sheetScroll);
      for (var i = 0; i < 3; i++) {
        await tap(plus, 450);
      }
      await tap(find.byTooltip('เพซเร็วขึ้น'), 600);
      await wait(800);
      await glide(-420, on: sheetScroll);
      await glide(-420, on: sheetScroll);
      await wait(800);
      await tap(find.text('บันทึกและเพิ่มลงตาราง'), 1800);
      await wait(1500);
      await glide(-400);
      await glide(-400);
      await wait(800);
      await toTop();
      await back();
    });
    await toTop();

    // --- 6. Record a run (simulated GPS): laps, pause, map, save -----
    final debug = home.read<DebugCubit>();
    debug.setGps(
      const GpsSimulation(enabled: true, speed: 30, route: SimRoute.lumpini),
    );
    await tap(find.byTooltip('เริ่มบันทึก'), 1500);
    await waitFor(find.byTooltip('เริ่ม'));
    await step('record types', () async {
      await tap(find.text('ปั่นจักรยาน').last, 1000);
      await tap(find.text('เดินป่า').last, 1000);
      await tap(find.text('วิ่ง').last, 1200);
    });
    await tap(find.byTooltip('เริ่ม'), 1000);
    await waitFor(find.text('REC'));
    await wait(9000);
    await step('lap', () async {
      await tap(find.text('เพิ่ม Lap'), 1500);
    });
    await wait(5000);
    await step('map view', () async {
      await tap(find.byTooltip('มุมมองแผนที่'), 5000);
      await tap(find.byTooltip('มุมมองเส้นทาง'), 1500);
    });
    await step('pause / resume', () async {
      await tap(find.byTooltip('หยุดชั่วคราว'), 2500);
      await tap(find.byTooltip('ทำต่อ'), 1000);
    });
    await wait(7000);
    await tap(find.byTooltip('จบและบันทึก'), 1000);
    await waitFor(
      find.text('ใส่เส้นทางและสถิติลงรูปภาพ'),
      timeout: const Duration(seconds: 40),
    );
    debug.setGps(const GpsSimulation());
    await wait(3000);
    await step('new activity detail', () async {
      for (var i = 0; i < 5; i++) {
        await glide(-420);
        await wait(500);
      }
      await toTop();
    });

    // --- 7. Share studio --------------------------------------------
    await step('share studio', () async {
      await scrollTo(find.text('ใส่เส้นทางและสถิติลงรูปภาพ'));
      await tap(find.text('ใส่เส้นทางและสถิติลงรูปภาพ'), 1500);
      await waitFor(find.text('สตูดิโอแชร์รูป'));
      await wait(1500);
      final cubit = tester
          .element(find.text('สตูดิโอแชร์รูป'))
          .read<PhotoOverlayCubit>();
      final photo = File(photoPath);
      if (photoPath.isNotEmpty && photo.existsSync()) {
        // Stands in for the gallery picker, which is native UI.
        // ignore: invalid_use_of_protected_member
        cubit.emit(cubit.state.copyWith(photo: await photo.readAsBytes()));
        await wait(2000);
      }
      for (final layout in ['กระจก', 'ครบ', 'ตัวเลข', 'เส้นทาง', 'คลาสสิก']) {
        await tap(find.text(layout).last, 1600);
      }
      await tap(find.text('เพซ').last, 1200);
      await tap(find.text('EN').last, 1500);
      await tap(find.text('EN').last, 1000);
      await tap(find.text('โลโก้').last, 1200);
      await tap(find.text('โลโก้').last, 1000);
      await tap(find.text('พื้นใส').last, 2200);
      await tap(find.text('พื้นใส').last, 1500);
      await tap(find.text('บันทึกรูป'), 2500);
      await back();
    });
    await back();
    await waitFor(find.text('พร้อมออกไปวิ่งหรือยัง?'));
    await wait(1500);

    // The run ticked off today's plan.
    await step('schedule after the run', () async {
      await scrollTo(find.text('ดูตาราง'));
      await tap(find.text('ดูตาราง'), 2500);
      await glide(-350);
      await wait(1500);
      await back();
      await toTop();
    });

    // --- 8. Sign up → 07.1 merge device data → sync -----------------
    await tap(find.byTooltip('บัญชี').first, 1500);
    await waitFor(find.text('ข้อมูลผู้ใช้'));
    await tap(find.text('สมัครสมาชิกหรือเข้าสู่ระบบ'), 1500);
    await waitFor(find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    await wait(1200);
    await type(find.byType(TextField).first, email);
    await type(find.byType(TextField).last, password);
    await tap(find.text('สร้างบัญชี'), 1500);
    await waitFor(find.text('ผูกและโอนย้ายข้อมูลเข้าบัญชี'));
    await wait(2500);
    final sheetScroll = find
        .descendant(
          of: find.byType(GuestLinkSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await step('guest sheet scroll', () => glide(-300, on: sheetScroll));
    final merge = find.byKey(const Key('guest-merge'));
    await tester.scrollUntilVisible(merge, 200, scrollable: sheetScroll);
    await wait(1200);
    await tap(merge, 1500);
    await waitFor(find.text('ซิงก์ตอนนี้'));
    await wait(1500);
    await tap(find.text('ซิงก์ตอนนี้'), 1000);
    await home.read<SyncCubit>().sync();
    await wait(3000);
    await step('account scroll', () async {
      await glide(-350);
      await wait(1200);
      await toTop();
    });
    await back();
    await wait(800);
    // Signed in, the profile grows and comes back scrolled down.
    await toTop();
    await waitFor(find.text('ข้อมูลผู้ใช้'));
    await wait(2000);
    await step('signed-in profile scroll', () async {
      await glide(-400);
      await wait(800);
      await toTop();
    });
    await back();
    await wait(1500);
    await step('home signed in', () async {
      await glide(-400);
      await glide(-400);
      await glide(-400);
      await toTop();
    });

    // --- 9. Delete the account (App Store requirement) --------------
    await tap(find.byTooltip('บัญชี').first, 1500);
    await waitFor(find.text('ข้อมูลผู้ใช้'));
    await scrollTo(find.text('บัญชีและซิงก์ข้อมูล'));
    await tap(find.text('บัญชีและซิงก์ข้อมูล'), 1500);
    await waitFor(find.text('ลบบัญชี'));
    await tester.ensureVisible(find.text('ลบบัญชี'));
    await wait(1200);
    await tap(find.text('ลบบัญชี'), 1500);
    await waitFor(find.text('ลบบัญชีถาวร?'));
    await tap(find.text('ลบบัญชี').last, 1500);
    await waitFor(find.text('ซิงก์กิจกรรมข้ามเครื่อง'));
    await wait(2500);
    await back();
    await wait(1000);
    await back();
    await wait(2500);

    debugPrint('DEMO_END');
    await wait(1500);
  });
}
