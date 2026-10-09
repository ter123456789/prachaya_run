import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Round glass button used for back / more / secondary actions.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  /// Lime primary variant (e.g. the big play/pause button).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Material(
      color: filled ? AppColors.lime : AppColors.glassFill,
      shape: CircleBorder(
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: size * 0.42,
            color: filled
                ? AppColors.onLime
                : enabled
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
        ),
      ),
    );
    final decorated = filled
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(color: AppColors.glassBorder, width: 8),
            ),
            child: button,
          )
        : button;
    return tooltip == null
        ? decorated
        : Tooltip(message: tooltip, child: decorated);
  }
}
