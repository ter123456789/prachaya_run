import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/track_point.dart';
import 'package:prachaya_run/features/activity/domain/services/vehicle_detector.dart';

import '../../../helpers/fakes.dart';

void main() {
  VehicleDetector detector([ActivityType type = ActivityType.run]) =>
      VehicleDetector(VehicleThresholds.forType(type));

  List<VehicleChange> feed(VehicleDetector d, List<TrackPoint> fixes) => [
    for (final fix in fixes) ?d.add(fix),
  ];

  DateTime at(int second) => t0.add(Duration(seconds: second));

  test('a run with fast intervals is never a vehicle', () {
    final d = detector();
    final fixes = journey([(300, 4.5), (30, 6.5), (60, 3), (30, 6.5)]);
    expect(feed(d, fixes), isEmpty);
    expect(d.inVehicle, isFalse);
  });

  test('GPS jitter on a standing phone is not a ride', () {
    final d = detector();
    final fixes = [
      for (var i = 1; i <= 120; i++)
        TrackPoint(
          latitude: 13.7 + (i.isEven ? 0.0001 : -0.0001),
          longitude: 100.5 + (i % 3 == 0 ? 0.0001 : 0),
          timestamp: at(i),
          accuracyMeters: 15,
        ),
    ];
    expect(feed(d, fixes), isEmpty);
  });

  test('one GPS jump is not a ride', () {
    final d = detector();
    final before = journey([(60, 3)]);
    final jump = TrackPoint(
      latitude: before.last.latitude + 0.0015,
      longitude: 100.5,
      timestamp: at(61),
      accuracyMeters: 20,
    );
    final after = journey([(60, 3)], startSecond: 61, startMeters: 183);
    expect(feed(d, [...before, jump, ...after]), isEmpty);
  });

  test('inaccurate fixes are ignored', () {
    final d = detector();
    final fixes = [
      for (final fix in journey([(60, 15)]))
        TrackPoint(
          latitude: fix.latitude,
          longitude: fix.longitude,
          timestamp: fix.timestamp,
          accuracyMeters: 50,
        ),
    ];
    expect(feed(d, fixes), isEmpty);
  });

  test('a car ride is dated from the last running fix', () {
    final d = detector();
    final changes = feed(d, journey([(60, 3.5), (60, 15)]));
    expect(changes, [VehicleChange(inVehicle: true, since: at(60))]);
    expect(d.inVehicle, isTrue);
  });

  test('getting out is dated from when the car stopped', () {
    final d = detector();
    final changes = <VehicleChange>[];
    List<TrackPoint>? backfill;
    for (final fix in journey([(60, 3.5), (120, 15), (120, 3)])) {
      final change = d.add(fix);
      if (change == null) continue;
      changes.add(change);
      if (!change.inVehicle) backfill = d.fixesSince(change.since);
    }
    expect(changes, [
      VehicleChange(inVehicle: true, since: at(60)),
      VehicleChange(inVehicle: false, since: at(180)),
    ]);
    // Everything since getting out is still there to fill the track in.
    expect(backfill!.first.timestamp, at(180));
    expect(backfill.length, greaterThan(60));
  });

  test('a car stuck in traffic for less than a minute stays a vehicle', () {
    final d = detector();
    final changes = feed(d, journey([(60, 3.5), (60, 15), (45, 1), (60, 15)]));
    expect(changes, [VehicleChange(inVehicle: true, since: at(60))]);
  });

  test('rides allow a fast descent but not a car on the expressway', () {
    expect(feed(detector(ActivityType.ride), journey([(300, 17)])), isEmpty);
    final changes = feed(
      detector(ActivityType.ride),
      journey([(60, 8), (60, 25)]),
    );
    expect(changes, [VehicleChange(inVehicle: true, since: at(60))]);
  });

  test('reset needs a fresh window of fast fixes', () {
    final d = detector();
    feed(d, journey([(60, 15)]));
    expect(d.inVehicle, isTrue);
    d.reset();
    expect(d.inVehicle, isFalse);
    final more = journey([(30, 15)], startSecond: 60, startMeters: 900);
    final changes = feed(d, more);
    expect(changes, hasLength(1));
    expect(changes.single.inVehicle, isTrue);
    expect(d.fixesSince(t0), hasLength(30));
  });
}
