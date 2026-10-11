import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// Frosted neo-glass panel: translucent fill, hairline rim lit from the top.
///
/// [blur] only matters over imagery (maps, photos); on the plain dark
/// canvas leave it off to save GPU work. Tappable cards spring on press.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = false,
    this.strong = false,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;

  /// Slightly more opaque fill, for content over busy backgrounds.
  final bool strong;

  /// Overrides the glass fill (e.g. an opaque surface tier).
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color,
        border: Border.all(color: AppColors.glassBorder),
        gradient: color != null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: strong
                    ? const [Color(0x2EFFFFFF), Color(0x14FFFFFF)]
                    : const [Color(0x14FFFFFF), Color(0x08FFFFFF)],
              ),
      ),
      child: Stack(
        children: [
          // Specular top rim.
          Positioned(
            left: radius * 0.6,
            right: radius * 0.6,
            top: 0,
            height: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00FFFFFF),
                    AppColors.glassHighlight,
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    if (blur) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      );
    }
    content = ClipRRect(borderRadius: borderRadius, child: content);
    return onTap == null ? content : Pressable(onTap: onTap, child: content);
  }
}
