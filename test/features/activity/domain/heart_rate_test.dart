import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/heart_rate.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_measurement.dart';
import 'package:prachaya_run/features/activity/domain/services/heart_rate_summary.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('uint8 heart rate, contact not supported', () {
      final r = parseHeartRateMeasurement([0x00, 72])!;
      expect(r.bpm, 72);
      expect(r.skinContact, isNull);
      expect(r.rrIntervals, isEmpty);
      expect(r.isUsable, isTrue);
    });

    test('uint16 little-endian heart rate', () {
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01])!.bpm, 300);
    });

    test('sensor contact bits', () {
      expect(parseHeartRateMeasurement([0x06, 150])!.skinContact, isTrue);
      final off = parseHeartRateMeasurement([0x04, 150])!;
      expect(off.skinContact, isFalse);
      expect(off.isUsable, isFalse);
    });

    test('skips energy expended, reads RR intervals', () {
      // Flags: uint8 HR, energy present, RR present. 1024 = one second.
      final r = parseHeartRateMeasurement([
        0x18, 60, 0x10, 0x00, 0x00, 0x04, 0x00, 0x02, //
      ])!;
      expect(r.bpm, 60);
      expect(r.rrIntervals, [
        const Duration(seconds: 1),
        const Duration(milliseconds: 500),
      ]);
    });

    test('malformed values', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x40]), isNull);
    });

    test('out of range readings are not usable', () {
      expect(parseHeartRateMeasurement([0x00, 0])!.isUsable, isFalse);
      expect(parseHeartRateMeasurement([0x01, 0x05, 0x01])!.isUsable, isFalse);
    });
  });

  group('summarizeHeartRate', () {
    HeartRateSample at(int seconds, int bpm) => HeartRateSample(
      timestamp: t0.add(Duration(seconds: seconds)),
      bpm: bpm,
    );

    test('null without samples', () {
      expect(summarizeHeartRate(const []), isNull);
    });

    test('time-weighted average, max and zone times', () {
      // 10 s at 100, 10 s at 150, then one last sample at 160.
      final samples = [
        for (var s = 0; s < 10; s++) at(s, 100),
        for (var s = 10; s < 20; s++) at(s, 150),
        at(20, 160),
      ];
      final summary = summarizeHeartRate(
        samples,
        zoneLowBpm: [96, 115, 134, 153, 172],
      )!;
      expect(summary.averageBpm, 127); // (100·10 + 150·10 + 160·1) / 21
      expect(summary.maxBpm, 160);
      expect(summary.zoneTimes, [
        const Duration(seconds: 10),
        Duration.zero,
        const Duration(seconds: 10),
        const Duration(seconds: 1),
        Duration.zero,
      ]);
      expect(summary.sparse, isFalse);
    });

    test('a gap counts for at most five seconds', () {
      // The sensor dropped out for 10 minutes after the first sample.
      final summary = summarizeHeartRate(
        [at(0, 100), at(600, 160)],
        zoneLowBpm: [96, 115, 134, 153, 172],
      )!;
      expect(summary.zoneTimes[0], const Duration(seconds: 5));
      expect(summary.zoneTimes[3], const Duration(seconds: 1));
    });

    test('below zone 1 is not counted; no zones gives none', () {
      final summary = summarizeHeartRate(
        [at(0, 80), at(1, 80)],
        zoneLowBpm: [96, 115, 134, 153, 172],
      )!;
      expect(summary.zoneTimes.every((t) => t == Duration.zero), isTrue);
      expect(summarizeHeartRate([at(0, 80)])!.zoneTimes, isEmpty);
    });

    test('samples minutes apart are sparse', () {
      final summary = summarizeHeartRate([
        for (var m = 0; m < 10; m++) at(m * 60, 140),
      ])!;
      expect(summary.sparse, isTrue);
    });
  });
}
