import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/route_shape.dart';

/// "Luminescent track" on a dotted telemetry grid: the route draws itself
/// in, glowing lime with a mint start ring and a lime end ring. Works
/// offline (no map tiles). With [live] the end marker pulses.
class RouteCanvas extends StatefulWidget {
  const RouteCanvas({
    super.key,
    required this.shape,
    this.padding = 0.12,
    this.live = false,
    this.grid = true,
    this.animate = true,
  });

  final RouteShape shape;

  /// Inset of the route inside the canvas, as a share of the shorter side.
  final double padding;
  final bool live;
  final bool grid;
  final bool animate;

  @override
  State<RouteCanvas> createState() => _RouteCanvasState();
}

class _RouteCanvasState extends State<RouteCanvas>
    with TickerProviderStateMixin {
  late final _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || !widget.animate || widget.live) {
      _draw.value = 1;
    } else if (_draw.value == 0) {
      _draw.forward();
    }
    if (widget.live && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_draw, _pulse]),
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _RouteCanvasPainter(
            shape: widget.shape,
            progress: Curves.easeInOutCubic.transform(_draw.value),
            pulse: widget.live ? _pulse.value : null,
            padding: widget.padding,
            grid: widget.grid,
          ),
        ),
      ),
    );
  }
}

class _RouteCanvasPainter extends CustomPainter {
  _RouteCanvasPainter({
    required this.shape,
    required this.progress,
    required this.pulse,
    required this.padding,
    required this.grid,
  });

  final RouteShape shape;
  final double progress;
  final double? pulse;
  final double padding;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final dot = Paint()..color = const Color(0x14FFFFFF);
      const gap = 18.0;
      for (var y = gap / 2; y < size.height; y += gap) {
        for (var x = gap / 2; x < size.width; x += gap) {
          canvas.drawCircle(Offset(x, y), 1, dot);
        }
      }
    }
    if (shape.isEmpty) return;

    final inset = math.min(size.width, size.height) * padding;
    final box = (Offset.zero & size).deflate(inset);
    // Fit the unit box, keeping proportions, centred.
    final aspect = shape.aspectRatio.isFinite ? shape.aspectRatio : 1.0;
    var w = box.width;
    var h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    final side = math.max(w, h);
    final origin = box.center - Offset(side / 2, side / 2);
    Offset toCanvas(ShapePoint p) => origin + Offset(p.x * side, p.y * side);

    final full = Path();
    for (final segment in shape.segments) {
      final first = toCanvas(segment.first);
      full.moveTo(first.dx, first.dy);
      for (final p in segment.skip(1)) {
        final o = toCanvas(p);
        full.lineTo(o.dx, o.dy);
      }
    }

    // Trim to the drawn share of the total length.
    final metrics = full.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, m) => s + m.length);
    var remaining = total * progress;
    final drawn = Path();
    Offset? tip;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final len = math.min(remaining, m.length);
      drawn.addPath(m.extractPath(0, len), Offset.zero);
      tip = m.getTangentForOffset(len)?.position;
      remaining -= len;
    }

    Paint stroke(double width, Color color, [double blur = 0]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

    canvas.drawPath(
      drawn,
      stroke(14, AppColors.lime.withValues(alpha: 0.28), 10),
    );
    canvas.drawPath(drawn, stroke(5, AppColors.lime));
    canvas.drawPath(drawn, stroke(1.6, const Color(0xCCFFFFFF)));

    final start = toCanvas(shape.segments.first.first);
    _ring(canvas, start, AppColors.mint, 7);
    if (tip != null) {
      final p = pulse;
      if (p != null) {
        canvas.drawCircle(
          tip,
          10 + 14 * p,
          Paint()..color = AppColors.lime.withValues(alpha: 0.35 * (1 - p)),
        );
      }
      if (progress >= 1 || p != null) _ring(canvas, tip, AppColors.lime, 8);
    }
  }

  void _ring(Canvas canvas, Offset c, Color color, double r) {
    canvas.drawCircle(
      c,
      r + 4,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(c, r * 0.45, Paint()..color = AppColors.background);
  }

  @override
  bool shouldRepaint(_RouteCanvasPainter old) =>
      old.shape != shape ||
      old.progress != progress ||
      old.pulse != pulse ||
      old.padding != padding ||
      old.grid != grid;
}
