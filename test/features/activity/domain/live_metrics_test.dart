import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/services/live_metrics.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('speed over the recent window of the last segment', () {
    // pointAt steps 0.001° (≈111 m) every 30 s ≈ 3.7 m/s.
    final segments = [
      [for (var i = 0; i < 5; i++) pointAt(i, secondsPerStep: 30)],
    ];
    final speed = recentSpeedMps(
      segments,
      window: const Duration(seconds: 60),
    )!;
    expect(speed, closeTo(111.2 / 30, 0.1));
  });

  test('null without enough recent data', () {
    expect(recentSpeedMps(const []), isNull);
    expect(
      recentSpeedMps([
        [pointAt(0)],
      ]),
      isNull,
    );
    expect(
      recentSpeedMps([
        [pointAt(0, secondsPerStep: 1), pointAt(1, secondsPerStep: 1)],
      ]),
      isNull,
    );
  });
}
