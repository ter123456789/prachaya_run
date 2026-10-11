import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/services/location_tracker.dart';
import 'package:prachaya_run/features/debug/data/debug_http_client.dart';
import 'package:prachaya_run/features/debug/data/simulated_location_tracker.dart';
import 'package:prachaya_run/features/debug/data/virtual_clock.dart';
import 'package:prachaya_run/features/debug/domain/entities/gps_simulation.dart';

import '../../helpers/fakes.dart';

void main() {
  test('virtual clock runs faster and resets to real time', () {
    final clock = VirtualClock()..speed = 60;
    final before = clock.now();
    // Busy-wait a few real milliseconds.
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < 20) {}
    expect(clock.now().difference(before).inMilliseconds, greaterThan(600));

    clock.reset();
    expect(
      clock.now().difference(DateTime.now()).inMilliseconds.abs(),
      lessThan(50),
    );
  });

  test('simulated tracker: one fix per simulated second, sped up', () {
    fakeAsync((async) {
      final tracker = SimulatedLocationTracker(
        FakeLocationTracker(),
        VirtualClock(),
      )..settings = const GpsSimulation(enabled: true, speed: 10, noise: false);
      final fixes = <TrackPoint>[];
      LocationAccess? access;
      tracker.requestAccess().then((a) => access = a);
      async.flushMicrotasks();
      final sub = tracker.watch(ActivityType.run).listen(fixes.add);

      async.elapse(const Duration(seconds: 1)); // 10 simulated seconds
      expect(access, LocationAccess.granted);
      expect(fixes, hasLength(10));

      Object? error;
      sub.onError((Object e) => error = e);
      tracker.dropSignal();
      async.flushMicrotasks();
      expect(error, isNotNull);
      sub.cancel();
    });
  });

  test('disabled simulation uses the real GPS', () async {
    final real = FakeLocationTracker(access: LocationAccess.denied);
    final tracker = SimulatedLocationTracker(real, VirtualClock());
    expect(await tracker.requestAccess(), LocationAccess.denied);
  });

  test('debug http: offline and a one-time token_expired', () async {
    var sent = 0;
    final client = DebugHttpClient(
      MockClient((_) async {
        sent++;
        return http.Response('{}', 200);
      }),
    );
    final url = Uri.parse('http://api.test/activities');
    const auth = {'Authorization': 'Bearer x'};

    client.offline = true;
    await expectLater(
      client.get(url, headers: auth),
      throwsA(isA<http.ClientException>()),
    );
    client.offline = false;

    client.expireNext = true;
    final expired = await client.get(url, headers: auth);
    expect(expired.statusCode, 401);
    expect(expired.body, contains('token_expired'));
    expect(sent, 0);

    expect((await client.get(url, headers: auth)).statusCode, 200);
    expect(sent, 1);
  });
}
