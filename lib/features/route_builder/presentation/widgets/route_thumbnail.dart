import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/services/route_geometry.dart';

/// A route's outline in a small square, north up, without map tiles.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail(this.points, {super.key, this.size = 64});

  final List<GeoPoint> points;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: CustomPaint(painter: _OutlinePainter(points)),
  );
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.points);

  final List<GeoPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final xy = LocalPlane(points.first).projectAll(points);
    final minX = xy.map((p) => p.x).reduce(math.min);
    final maxX = xy.map((p) => p.x).reduce(math.max);
    final minY = xy.map((p) => p.y).reduce(math.min);
    final maxY = xy.map((p) => p.y).reduce(math.max);
    final extent = math.max(maxX - minX, maxY - minY);
    if (extent == 0) return;
    final box = (Offset.zero & size).deflate(size.shortestSide * 0.18);
    final scale = box.shortestSide / extent;
    final origin =
        box.center -
        Offset((maxX - minX) * scale / 2, -(maxY - minY) * scale / 2);
    Offset toCanvas(PlanePoint p) =>
        origin + Offset((p.x - minX) * scale, -(p.y - minY) * scale);

    final path = Path()..moveTo(toCanvas(xy.first).dx, toCanvas(xy.first).dy);
    for (final p in xy.skip(1)) {
      final o = toCanvas(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.lime.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = AppColors.lime
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.points != points;
}
