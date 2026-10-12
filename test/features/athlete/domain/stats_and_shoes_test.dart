import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/athlete/domain/entities/shoe.dart';
import 'package:prachaya_run/features/athlete/domain/services/all_time_stats.dart';
import 'package:prachaya_run/features/athlete/domain/services/shoe_usage.dart';

ActivitySummary _a(
  String id, {
  ActivityType type = ActivityType.run,
  double meters = 5000,
  Duration time = const Duration(minutes: 25),
  DateTime? at,
  String? shoe,
}) => ActivitySummary(
  id: id,
  type: type,
  title: id,
  startedAt: at ?? DateTime(2026, 10, 1),
  movingTime: time,
  distanceMeters: meters,
  elevationGainMeters: 0,
  shoeId: shoe,
);

void main() {
  group('all-time stats', () {
    test('totals every activity; pace over runs only', () {
      final stats = AllTimeStats.from([
        _a('1', meters: 10000, time: const Duration(minutes: 50)),
        _a('2', meters: 5000, time: const Duration(minutes: 30)),
        _a(
          '3',
          type: ActivityType.ride,
          meters: 20000,
          time: const Duration(hours: 1),
          at: DateTime(2024, 3, 2),
        ),
      ]);
      expect(stats.distanceMeters, 35000);
      expect(stats.movingTime, const Duration(hours: 2, minutes: 20));
      expect(stats.count, 3);
      expect(stats.runCount, 2);
      expect(stats.runShare, closeTo(2 / 3, 1e-9));
      // 15 km in 80 min = 5:20 /km.
      expect(1000 / stats.runAverageSpeedMps, closeTo(320, 1e-6));
      expect(stats.firstYear, 2024);
    });

    test('empty', () {
      final stats = AllTimeStats.from(const []);
      expect(stats.count, 0);
      expect(stats.runShare, 0);
      expect(stats.runAverageSpeedMps, 0);
      expect(stats.firstYear, isNull);
    });
  });

  group('shoe usage', () {
    const pegasus = Shoe(id: 's1', name: 'Pegasus', primary: true);
    const old = Shoe(
      id: 's2',
      name: 'Alphafly',
      lifespanKm: 400,
      startDistanceMeters: 390000,
    );

    test('start distance plus linked activities', () {
      final usage = shoeUsage(
        [pegasus, old],
        [
          _a('1', meters: 10000, shoe: 's1'),
          _a('2', meters: 8000, shoe: 's1'),
          _a('3', meters: 12000, shoe: 's2'),
          _a('4', meters: 5000), // no shoe
          _a('5', meters: 9000, shoe: 'deleted-shoe'), // unknown: ignored
        ],
      );
      final byId = {for (final u in usage) u.shoe.id: u};
      expect(byId['s1']!.usedMeters, 18000);
      expect(byId['s1']!.percent, 3); // 18 of 600 km
      expect(byId['s2']!.usedMeters, 402000);
      expect(byId['s2']!.wornOut, isTrue);
      expect(byId['s2']!.fraction, 1);
      expect(byId['s2']!.percent, 101);
    });

    test('primary first, retired last', () {
      final usage = shoeUsage([
        const Shoe(id: 'r', name: 'A retired', retired: true),
        const Shoe(id: 'b', name: 'B'),
        const Shoe(id: 'p', name: 'Z primary', primary: true),
      ], const []);
      expect([for (final u in usage) u.shoe.id], ['p', 'b', 'r']);
    });

    test('validation matches the server', () {
      expect(isValidShoe(pegasus), isTrue);
      expect(isValidShoe(const Shoe(id: 'x', name: '  ')), isFalse);
      expect(
        isValidShoe(const Shoe(id: 'x', name: 'a', lifespanKm: 40)),
        isFalse,
      );
      expect(
        isValidShoe(const Shoe(id: 'x', name: 'a', startDistanceMeters: -1)),
        isFalse,
      );
    });
  });
}
