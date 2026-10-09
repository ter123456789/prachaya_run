import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/data/models/activity_row_mapper.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('round-trips an activity with multiple segments', () {
    final activity = Activity(
      id: 'a1',
      type: ActivityType.hike,
      title: 'เดินป่าตอนเช้า',
      startedAt: t0,
      endedAt: t0.add(const Duration(hours: 1)),
      movingTime: const Duration(minutes: 50),
      segments: [
        [pointAt(0, altitude: 100, accuracy: 5), pointAt(1)],
        [pointAt(3), pointAt(4, altitude: 120)],
      ],
    );

    final row = ActivityRowMapper.activityToRow(activity);
    final pointRows = ActivityRowMapper.pointsToRows(activity).toList();
    final restored = ActivityRowMapper.activityFromRows(row, pointRows);

    expect(restored.type, ActivityType.hike);
    expect(restored.movingTime, activity.movingTime);
    expect(restored.segments, activity.segments);

    final summary = ActivityRowMapper.summaryFromRow(row);
    expect(summary.distanceMeters, activity.distanceMeters);
  });
}
