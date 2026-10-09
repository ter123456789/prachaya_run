import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('splits per km use GPS time and interpolate the boundary', () {
    // 20 steps × 111.2 m = ~2224 m at 30 s per step.
    final activity = Activity(
      id: 'a',
      type: ActivityType.run,
      title: 'run',
      startedAt: t0,
      endedAt: t0,
      movingTime: const Duration(minutes: 10),
      segments: [List.generate(21, pointAt)],
    );

    final splits = activity.splits();
    expect(splits, hasLength(3));
    expect(splits[0].distanceMeters, 1000);
    // 1000 m / (111.2 m per 30 s) ≈ 269.8 s
    expect(splits[0].duration.inSeconds, closeTo(270, 1));
    expect(splits[2].distanceMeters, closeTo(223.9, 1));
  });

  test('summary average speed uses moving time', () {
    final activity = Activity(
      id: 'a',
      type: ActivityType.ride,
      title: 'ride',
      startedAt: t0,
      endedAt: t0,
      movingTime: const Duration(seconds: 100),
      segments: [
        [pointAt(0), pointAt(9)],
      ],
    );
    expect(activity.summary.averageSpeedMps, closeTo(10.0, 0.1));
  });
}
