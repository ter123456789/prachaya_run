import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/route_shape.dart';

/// Draws a [RouteShape] centred in the canvas, keeping its proportions.
class RoutePainter extends CustomPainter {
  RoutePainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
    this.shadow = true,
  });

  final RouteShape shape;
  final Color color;
  final double strokeWidth;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    if (shape.isEmpty) return;
    final side = math.min(size.width, size.height);
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    Offset toCanvas(ShapePoint p) => origin + Offset(p.x * side, p.y * side);

    final path = Path();
    for (final segment in shape.segments) {
      final first = toCanvas(segment.first);
      path.moveTo(first.dx, first.dy);
      for (final point in segment.skip(1)) {
        final o = toCanvas(point);
        path.lineTo(o.dx, o.dy);
      }
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    if (shadow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = strokeWidth * 1.6
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth),
      );
    }
    canvas.drawPath(path, stroke..color = color);

    final start = toCanvas(shape.segments.first.first);
    final end = toCanvas(shape.segments.last.last);
    final dot = Paint()..color = color;
    canvas.drawCircle(start, strokeWidth * 1.1, dot);
    canvas.drawCircle(end, strokeWidth * 1.6, dot);
    canvas.drawCircle(
      end,
      strokeWidth * 0.7,
      Paint()..color = shadow ? Colors.black54 : Colors.white,
    );
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.shadow != shadow;
}
