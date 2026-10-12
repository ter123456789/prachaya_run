import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/athlete/domain/services/body_metrics.dart';
import 'package:prachaya_run/features/athlete/domain/services/heart_rate_zones.dart';

void main() {
  final today = DateTime(2026, 10, 12);

  group('Max HR', () {
    test('Tanaka: 208 − 0.7 × age, rounded', () {
      expect(tanakaMaxHr(24), 191); // 191.2
      expect(tanakaMaxHr(30), 187);
      expect(tanakaMaxHr(45), 177); // 176.5 rounds up
    });

    test('age comes from the birth year', () {
      expect(ageIn(2002, today), 24);
      expect(ageIn(null, today), isNull);
    });

    test('an entered Max HR wins over the estimate', () {
      expect(
        resolveMaxHr(enteredBpm: 195, birthYear: 2002, today: today),
        const MaxHeartRate(195, MaxHrSource.entered),
      );
      expect(
        resolveMaxHr(birthYear: 2002, today: today),
        const MaxHeartRate(191, MaxHrSource.tanaka),
      );
      expect(resolveMaxHr(today: today), isNull);
    });
  });

  group('zones', () {
    test('Max HR 191 gives the ranges shown in the design', () {
      final zones = heartRateZones(191);
      expect(
        [for (final z in zones) (z.lowBpm, z.highBpm)],
        [(96, 114), (115, 133), (134, 152), (153, 171), (172, 191)],
      );
      expect([for (final z in zones) z.highPercent], [60, 70, 80, 90, 100]);
    });

    test('bands touch but never overlap, even on exact percentages', () {
      for (final max in [150, 180, 191, 200, 213]) {
        final zones = heartRateZones(max);
        expect(zones.first.lowBpm, (max * 0.5).ceil());
        expect(zones.last.highBpm, max);
        for (var i = 1; i < zones.length; i++) {
          expect(zones[i].lowBpm, zones[i - 1].highBpm + 1, reason: '$max');
        }
      }
      // 200 bpm: 60 % is exactly 120, which starts zone 2.
      expect(heartRateZones(200)[1].lowBpm, 120);
      expect(heartRateZones(200)[0].highBpm, 119);
    });

    test('a different Max HR moves every zone', () {
      expect(heartRateZones(187).first.lowBpm, 94);
      expect(heartRateZones(187)[1], isNot(heartRateZones(191)[1]));
    });
  });

  group('BMI', () {
    test('weight ÷ height², banded for Asian adults', () {
      final v = bmi(weightKg: 64.5, heightCm: 175)!;
      expect(v, closeTo(21.06, 0.01));
      expect(bmiBand(v), BmiBand.normal);
      expect(bmiBand(18.4), BmiBand.underweight);
      expect(bmiBand(23), BmiBand.overweight);
      expect(bmiBand(27), BmiBand.obese1);
      expect(bmiBand(31), BmiBand.obese2);
    });

    test('the band follows the value shown (one decimal)', () {
      expect(bmiBand(22.96), BmiBand.overweight); // shown as 23.0
      expect(bmiBand(22.94), BmiBand.normal); // shown as 22.9
    });

    test('needs both weight and height', () {
      expect(bmi(weightKg: 60), isNull);
      expect(bmi(heightCm: 170), isNull);
    });
  });
}
