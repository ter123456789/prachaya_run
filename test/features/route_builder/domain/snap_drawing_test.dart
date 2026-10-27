import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/planned_route.dart';
import 'package:prachaya_run/features/route_builder/domain/repositories/route_snapper.dart';
import 'package:prachaya_run/features/route_builder/domain/services/route_geometry.dart';
import 'package:prachaya_run/features/route_builder/domain/usecases/snap_drawing.dart';

GeoPoint at(double north, double east) =>
    GeoPoint(13.73 + north / 111195, 100.54 + east / 108040);

/// Echoes the shape back, as if every point were on a road.
class EchoSnapper implements RouteSnapper {
  List<GeoPoint>? sent;
  RouteSnapException? failWith;

  @override
  Future<SnappedPath> snap(List<GeoPoint> shape) async {
    sent = shape;
    if (failWith case final e?) throw e;
    return SnappedPath(shape, pathLength(shape));
  }
}

void main() {
  test('drawnShape joins strokes, removes jitter and closes the loop', () {
    final wobbly = [
      for (var m = 0; m <= 400; m += 5) at(m.toDouble(), m % 10 == 0 ? 0 : 2),
    ];
    final second = [at(400, 0), at(400, 400)];
    final shape = drawnShape([wobbly, second], closed: true);
    expect(shape.first, at(0, 0));
    expect(shape.last, shape.first);
    // Start, the corner, the far end of the second stroke, back to start.
    expect(shape.length, lessThanOrEqualTo(6));
  });

  test('an open shape is not closed', () {
    final shape = drawnShape([
      [at(0, 0), at(0, 300), at(300, 300)],
    ], closed: false);
    expect(shape.last, at(300, 300));
  });

  test('sends evenly spaced points and scores the result', () async {
    final snapper = EchoSnapper();
    final plan = await SnapDrawing(snapper)([
      [at(0, 0), at(0, 500), at(500, 500), at(500, 0)],
    ], closed: true);

    final sent = snapper.sent!;
    for (var i = 1; i < sent.length; i++) {
      expect(distanceMeters(sent[i - 1], sent[i]), lessThanOrEqualTo(35.1));
    }
    expect(plan.drawn.last, plan.drawn.first);
    expect(plan.distanceMeters, closeTo(2000, 2));
    expect(plan.fit!.score, 100);
    // Collinear points along each edge are dropped again.
    expect(plan.route, hasLength(5));
  });

  test('rejects a single tap and shapes over 100 km', () async {
    final snapper = EchoSnapper();
    expect(
      () => SnapDrawing(snapper)([
        [at(0, 0)],
      ], closed: false),
      throwsA(isA<RouteValidationException>()),
    );
    expect(
      () => SnapDrawing(snapper)([
        [at(0, 0), at(101000, 0)],
      ], closed: false),
      throwsA(
        isA<RouteSnapException>().having(
          (e) => e.error,
          'error',
          RouteSnapError.tooLong,
        ),
      ),
    );
    expect(snapper.sent, isNull);
  });

  test('passes snapper failures through', () async {
    final snapper = EchoSnapper()
      ..failWith = const RouteSnapException(RouteSnapError.signedOut);
    expect(
      () => SnapDrawing(snapper)([
        [at(0, 0), at(0, 500)],
      ], closed: false),
      throwsA(isA<RouteSnapException>()),
    );
  });
}
