import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dark canvas with the soft lime glow bleeding down from the top edge.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child, this.glowHeight = 340});

  final Widget child;
  final double glowHeight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: glowHeight,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE6C7DC8C),
                    Color(0x805E7A24),
                    Color(0x000C0D0B),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
