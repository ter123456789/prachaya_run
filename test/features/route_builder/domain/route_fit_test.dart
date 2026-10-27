import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/services/route_fit.dart';
import 'package:prachaya_run/features/route_builder/domain/services/route_geometry.dart';

/// A point [north] / [east] metres from a fixed origin in Bangkok.
GeoPoint at(double north, double east) =>
    GeoPoint(13.73 + north / 111195, 100.54 + east / 108040);

/// A 500 m square, closed.
final square = [at(0, 0), at(0, 500), at(500, 500), at(500, 0), at(0, 0)];

void main() {
  test('tolerance is 6 % of the shape, between 30 and 120 m', () {
    expect(fitTolerance(square), closeTo(42.4, 0.5)); // 707 m diagonal
    expect(fitTolerance([at(0, 0), at(10, 10)]), 30);
    expect(fitTolerance([at(0, 0), at(5000, 5000)]), 120);
  });

  test('a route on the drawing scores 100', () {
    final fit = fitRoute(square, densify(square, 20));
    expect(fit.score, 100);
    expect(fit.offShape, isEmpty);
  });

  test('a route a few metres beside the drawing still scores 100', () {
    final shifted = [
      for (final p in square) GeoPoint(p.latitude + 15 / 111195, p.longitude),
    ];
    expect(fitRoute(square, shifted).score, 100);
  });

  test('a detour lowers the score and is reported', () {
    // Along the bottom edge, a 300 m excursion south around a block.
    final route = [
      at(0, 0),
      at(0, 200),
      at(-300, 200),
      at(-300, 300),
      at(0, 300),
      at(0, 500),
      at(500, 500),
      at(500, 0),
      at(0, 0),
    ];
    final fit = fitRoute(square, route);
    expect(fit.score, inInclusiveRange(60, 85));
    expect(fit.offShape, hasLength(1));
    final (start, end) = fit.offShape.single;
    expect(start, 1);
    expect(end, 4);
  });

  test('a route that covers half the drawing scores about 50', () {
    final half = [at(0, 0), at(0, 500), at(500, 500)];
    expect(fitRoute(square, half).score, inInclusiveRange(45, 55));
  });

  test('degenerate input scores 0', () {
    expect(fitRoute([at(0, 0)], square).score, 0);
    expect(fitRoute(square, const []).score, 0);
  });
}
