import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'count_up_text.dart';
import 'glass_card.dart';

/// Telemetry tile: small label (+ lime icon), big mono metric with unit,
/// optional footer line (delta, hint). The metric rolls up when [numeric]
/// is given.
class BentoStat extends StatelessWidget {
  const BentoStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.footer,
    this.footerColor,
    this.footerIcon,
    this.numeric,
    this.format,
    this.valueStyle = AppText.metricLg,
    this.valueColor,
    this.onTap,
  });

  final String label;

  /// Text shown when not animating (and the final text when animating).
  final String value;
  final String? unit;
  final IconData? icon;
  final String? footer;
  final Color? footerColor;
  final IconData? footerIcon;

  /// When set with [format], the metric counts up to this value.
  final double? numeric;
  final String Function(double)? format;
  final TextStyle valueStyle;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = valueStyle.copyWith(color: valueColor);
    final metric = numeric != null && format != null
        ? CountUpText(numeric!, format: format!, style: style)
        : Text(value, style: style);
    return GlassCard(
      radius: 20,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) Icon(icon, color: AppColors.lime, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                metric,
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: AppText.caption),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (footerIcon != null) ...[
                  Icon(
                    footerIcon,
                    size: 14,
                    color: footerColor ?? AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    footer!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: footerColor ?? AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
