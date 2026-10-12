import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/formatters.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/core/units/unit_labels.dart';
import 'package:prachaya_run/features/athlete/presentation/units.dart';

void main() {
  test('distance in km and miles', () {
    expect(formatDistance(5320, DistanceUnit.km), '5.32');
    expect(formatDistance(1609.344, DistanceUnit.mi), '1.00');
    expect(formatDistance(10000, DistanceUnit.mi), '6.21');
    expect(DistanceUnit.mi.toMeters(2), closeTo(3218.688, 1e-9));
  });

  test('pace per km and per mile', () {
    const speed = 1000 / 300; // 5:00 /km
    expect(formatPaceIn(speed, DistanceUnit.km), '5:00');
    expect(formatPaceIn(speed, DistanceUnit.mi), '8:03'); // 482.8 s
    expect(formatPaceIn(0.1, DistanceUnit.km), '--:--');
    expect(DistanceUnit.mi.paceFromPerKm(315), closeTo(506.94, 0.01));
    expect(formatPaceSeconds(315), '5:15');
    expect(formatPaceSecondsQuote(330), '5\'30"');
  });

  test('speed per hour', () {
    const speed = 5.0; // m/s
    expect(formatSpeedIn(speed, DistanceUnit.km), '18.0');
    expect(formatSpeedIn(speed, DistanceUnit.mi), '11.2');
  });

  test('labels', () {
    expect(DistanceUnit.km.short, 'กม.');
    expect(DistanceUnit.mi.short, 'ไมล์');
    expect(DistanceUnit.mi.paceSuffix, '/ไมล์');
    expect(DistanceUnit.mi.latinSpeed, 'MPH');
  });

  test('UnitFormat converts plan paces and wind', () {
    const mi = UnitFormat(DistanceUnit.mi);
    expect(mi.paceFromPerKm(315), '8\'27"');
    expect(mi.windFromKmh(16.09), '10 ไมล์/ชม.');
    expect(const UnitFormat(DistanceUnit.km).windFromKmh(12.4), '12 กม./ชม.');
  });

  test('Thai dates', () {
    final t = DateTime(2026, 5, 14, 18, 5); // Thursday
    expect(thaiWeekdayShort(t), 'พฤ.');
    expect(formatLongDate(t), 'พฤหัสบดี 14 พ.ค. 2569');
    expect(formatClock(t), '18:05');
  });
}
