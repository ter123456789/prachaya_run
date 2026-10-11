import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// Round button for back / share / delete / secondary actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.filled = false,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  /// Lime primary variant (e.g. the big play/pause button).
  final bool filled;

  /// e.g. [AppColors.negative] for delete.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Pressable(
      onTap: onPressed,
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.lime : AppColors.surfaceHigh,
          border: filled ? null : Border.all(color: AppColors.glassBorder),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.40),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: size * 0.44,
          color: filled
              ? AppColors.onLime
              : !enabled
              ? AppColors.textMuted
              : iconColor ?? AppColors.textPrimary,
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button),
    );
  }
}
