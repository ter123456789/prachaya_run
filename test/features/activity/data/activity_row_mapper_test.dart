import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/data/models/activity_row_mapper.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_origin.dart';
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

    final row = ActivityRowMapper.activityToRow(
      activity,
      updatedAt: t0,
      ownerId: null,
    );
    final pointRows = ActivityRowMapper.pointsToRows(activity).toList();
    final restored = ActivityRowMapper.activityFromRows(row, pointRows);

    expect(restored.type, ActivityType.hike);
    expect(restored.movingTime, activity.movingTime);
    expect(restored.segments, activity.segments);

    final summary = ActivityRowMapper.summaryFromRow(row);
    expect(summary.distanceMeters, activity.distanceMeters);
  });

  test('heart rate is stored as [t, bpm] pairs relative to the start', () {
    final a = sampleActivity();
    final activity = Activity(
      id: a.id,
      type: a.type,
      title: a.title,
      startedAt: a.startedAt,
      endedAt: a.endedAt,
      movingTime: a.movingTime,
      segments: a.segments,
      heartRate: sampleHeartRate(),
    );
    final column = ActivityRowMapper.heartRateToColumn(activity)!;
    expect(column, contains('[5000,128]'));
    final row = {
      ...ActivityRowMapper.activityToRow(
        activity,
        updatedAt: t0,
        ownerId: null,
      ),
      'heart_rate': column,
    };
    final restored = ActivityRowMapper.activityFromRows(
      row,
      ActivityRowMapper.pointsToRows(activity).toList(),
    );
    expect(restored.heartRate, sampleHeartRate());
    expect(ActivityRowMapper.heartRateToColumn(sampleActivity()), isNull);
  });

  test('origin and a no-track distance survive the row', () {
    final a = Activity(
      id: 'a',
      type: ActivityType.ride,
      title: 'ปั่นในร่ม',
      startedAt: t0,
      endedAt: t0.add(const Duration(hours: 1)),
      movingTime: const Duration(hours: 1),
      segments: const [],
      origin: const ActivityOrigin(OriginKind.health, device: 'Watch'),
      reportedDistanceMeters: 21000,
      reportedElevationGainMeters: 120,
    );
    final row = ActivityRowMapper.activityToRow(
      a,
      updatedAt: t0,
      ownerId: null,
    );
    final back = ActivityRowMapper.activityFromRows(row, const []);
    expect(back.origin, a.origin);
    expect(back.distanceMeters, 21000);
    expect(back.elevationGainMeters, 120);
    final summary = ActivityRowMapper.summaryFromRow(row);
    expect(summary.origin, a.origin);
    expect(summary.end, a.endedAt);
    expect(
      ActivityRowMapper.summaryFromRow(
        ActivityRowMapper.activityToRow(
          sampleActivity(),
          updatedAt: t0,
          ownerId: null,
        ),
      ).origin,
      ActivityOrigin.phone,
    );
  });
}
