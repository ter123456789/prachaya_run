import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/route_shape.dart';

import '../../../helpers/fakes.dart';

void main() {
  test('normalizes into the unit box, centred, north up', () {
    // Straight line north: tall and thin.
    final shape = RouteShape.fromSegments([
      [pointAt(0), pointAt(5), pointAt(10)],
    ]);
    final line = shape.segments.single;

    expect(line.first.y, closeTo(1, 1e-9)); // start at bottom (south)
    expect(line.last.y, closeTo(0, 1e-9)); // end at top (north)
    for (final p in line) {
      expect(p.x, closeTo(0.5, 1e-9)); // centred horizontally
    }
  });

  test('keeps true proportions using cos(latitude)', () {
    final shape = RouteShape.fromSegments(sampleActivity().segments);
    // 0.009° north vs 0.009° east at lat 13.7 → width/height ≈ cos(13.7°).
    expect(shape.aspectRatio, closeTo(0.9716, 0.001));
    expect(shape.segments, hasLength(2));
  });

  test('empty for tracks with fewer than two points', () {
    expect(
      RouteShape.fromSegments([
        [pointAt(0)],
      ]).isEmpty,
      isTrue,
    );
    expect(RouteShape.fromSegments([]).isEmpty, isTrue);
  });
}
