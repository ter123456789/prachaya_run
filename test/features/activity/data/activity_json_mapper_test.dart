import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/data/models/activity_json_mapper.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('times are ISO 8601 UTC with exactly milliseconds', () {
    final t = DateTime.utc(2026, 10, 11, 6, 0, 0, 12, 345);
    expect(ActivityJsonMapper.time(t), '2026-10-11T06:00:00.012Z');
  });

  test('activity round-trips through the API JSON', () {
    final activity = sampleActivity();
    final json = ActivityJsonMapper.activityToJson(activity, updatedAt: t0);

    expect(json['updatedAt'], ActivityJsonMapper.time(t0));
    expect(json['movingTimeMs'], activity.movingTime.inMilliseconds);

    final restored = ActivityJsonMapper.activityFromJson(json);
    expect(restored.id, activity.id);
    expect(restored.type, activity.type);
    expect(restored.startedAt, activity.startedAt);
    expect(restored.segments, activity.segments);
  });

  test('summary reads server-computed totals and deletedAt', () {
    final summary = ActivityJsonMapper.summaryFromJson({
      'id': 'a1',
      'type': 'ride',
      'title': 't',
      'startedAt': '2026-10-11T06:00:00.000Z',
      'endedAt': '2026-10-11T07:00:00.000Z',
      'movingTimeMs': 3600000,
      'updatedAt': '2026-10-11T07:00:01.000Z',
      'distanceM': 20123.5,
      'elevationGainM': 42,
      'deletedAt': '2026-10-12T00:00:00.000Z',
    });
    expect(summary.distanceMeters, 20123.5);
    expect(summary.elevationGainMeters, 42.0);
    expect(summary.isDeleted, isTrue);
    expect(summary.updatedAt.isUtc, isFalse);
  });
}
