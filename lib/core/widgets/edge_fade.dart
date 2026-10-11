import 'package:flutter/material.dart';

/// Softly fades scrolling content into the top (and optionally bottom)
/// edge instead of a hard cut.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.top = 20,
    this.bottom = 0,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final h = rect.height <= 0 ? 1.0 : rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [
            0,
            (top / h).clamp(0.0, 0.5),
            (1 - bottom / h).clamp(0.5, 1.0),
            1,
          ],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
