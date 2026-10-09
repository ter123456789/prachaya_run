import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass_card.dart';

/// "Label / big value + small unit" tile, optionally with a lime icon.
class GlassStatTile extends StatelessWidget {
  const GlassStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.footer,
    this.blur = false,
    this.valueSize = 22,
    this.centered = false,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Widget? footer;
  final bool blur;
  final double valueSize;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: blur,
      strong: blur,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.lime, size: 22),
            const SizedBox(height: 8),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
  }
}
