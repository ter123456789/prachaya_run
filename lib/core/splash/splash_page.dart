import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated launch screen shown after the native (plain dark) splash: the
/// app icon pops in with a lime ripple, a route line draws itself under the
/// wordmark, then the screen fades into [next].
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.next});

  final WidgetBuilder next;

  static const duration = Duration(milliseconds: 1700);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: SplashPage.duration,
  );

  Animation<double> _interval(double begin, double end, [Curve? curve]) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
      );

  late final _glow = _interval(0, 0.5);
  late final _icon = _interval(0.05, 0.45, Curves.easeOutBack);
  late final _iconFade = _interval(0.05, 0.3);
  late final _ripple = _interval(0.2, 0.75, Curves.easeOut);
  late final _wordmark = _interval(0.35, 0.7);
  late final _route = _interval(0.45, 0.95, Curves.easeInOutCubic);
  late final _tagline = _interval(0.6, 0.9);

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goNext();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    // Respect "remove animations" in the OS accessibility settings.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
    } else {
      _controller.forward();
    }
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: _glow.value,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.2),
                    radius: 1.1,
                    colors: [
                      Color(0xB3C7DC8C),
                      Color(0x405E7A24),
                      Color(0x000C0D0B),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple ring expanding out of the icon.
                        Opacity(
                          opacity: (1 - _ripple.value) * 0.8,
                          child: Container(
                            width: 120 + 100 * _ripple.value,
                            height: 120 + 100 * _ripple.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.lime,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _iconFade.value,
                          child: Transform.scale(
                            scale: lerpDouble(0.6, 1, _icon.value),
                            child: const _AppIcon(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: _wordmark.value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - _wordmark.value)),
                      child: const Text(
                        'PRACHAYA RUN',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomPaint(
                    size: const Size(180, 28),
                    painter: _RouteLinePainter(progress: _route.value),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _tagline.value,
                    child: const Text(
                      'วิ่ง · ปั่น · เดินป่า',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.lime, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.35),
            blurRadius: 32,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// A wavy lime "route" that draws itself from left to right.
class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(0, h * 0.7)
      ..cubicTo(w * 0.15, h * 0.1, w * 0.3, h * 0.1, w * 0.42, h * 0.55)
      ..cubicTo(w * 0.55, h * 1.0, w * 0.7, h * 0.9, w * 0.8, h * 0.4)
      ..cubicTo(w * 0.86, h * 0.1, w * 0.94, h * 0.15, w, h * 0.3);
    final metric = path.computeMetrics().first;
    final end = metric.length * progress;
    final drawn = metric.extractPath(0, end);
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = AppColors.lime,
    );
    final tip = metric.getTangentForOffset(end)?.position;
    if (tip != null) {
      canvas.drawCircle(tip, 4.5, Paint()..color = AppColors.lime);
      canvas.drawCircle(tip, 2, Paint()..color = AppColors.background);
    }
  }

  @override
  bool shouldRepaint(_RouteLinePainter old) => old.progress != progress;
}
