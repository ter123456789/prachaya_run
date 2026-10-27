import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/services/route_geometry.dart';

/// 0.001° latitude ≈ 111.2 m.
GeoPoint north(double meters) => GeoPoint(13.7 + meters / 111195, 100.5);

void main() {
  test('distance and path length', () {
    expect(distanceMeters(north(0), north(1000)), closeTo(1000, 1));
    expect(pathLength([north(0), north(300), north(1000)]), closeTo(1000, 1));
    expect(pathLength([north(0)]), 0);
  });

  test('simplify drops points on a straight line, keeps corners', () {
    final line = [for (var m = 0; m <= 500; m += 10) north(m.toDouble())];
    expect(simplify(line, 3), [line.first, line.last]);

    // An L: north 300 m, then east 300 m, with 1 m wobble on the way.
    const east = 0.0027765; // ≈ 300 m at 13.7°
    final l = [
      north(0),
      GeoPoint(north(150).latitude, 100.5 + 0.000009),
      north(300),
      GeoPoint(north(300).latitude, 100.5 + east / 2),
      GeoPoint(north(300).latitude, 100.5 + east),
    ];
    expect(simplify(l, 3), [l[0], l[2], l[4]]);
  });

  test('densify keeps every original point and caps the gap', () {
    final out = densify([north(0), north(100), north(105)], 30);
    expect(out.first, north(0));
    expect(out, contains(north(100)));
    expect(out.last, north(105));
    for (var i = 1; i < out.length; i++) {
      expect(distanceMeters(out[i - 1], out[i]), lessThanOrEqualTo(30.01));
    }
    expect(out, hasLength(6)); // 0, 25, 50, 75, 100, 105
  });

  test('distance to a line', () {
    final plane = LocalPlane(north(0));
    final line = plane.projectAll([north(0), north(1000)]);
    final beside = plane.project(GeoPoint(north(500).latitude, 100.50046));
    expect(distanceToLine(beside, line), closeTo(50, 1));
    expect(distanceToLine(plane.project(north(1100)), line), closeTo(100, 1));
  });

  test('diagonal of the bounding box', () {
    expect(diagonalMeters([north(0), north(400)]), closeTo(400, 1));
    expect(diagonalMeters([north(0)]), 0);
  });
}
