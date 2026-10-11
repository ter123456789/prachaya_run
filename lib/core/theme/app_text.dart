import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale. Prompt carries Thai and body copy; JetBrains Mono carries
/// telemetry digits (tabular, so counters never jitter). Mono styles fall
/// back to Prompt for Thai units such as "กม.".
abstract final class AppText {
  static const _mono = 'JetBrainsMono';
  static const _fallback = ['Prompt'];

  // Telemetry
  static const metricHero = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 44,
    height: 48 / 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.3,
    color: AppColors.textPrimary,
  );
  static const metricLg = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );
  static const metricMd = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 22,
    height: 26 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );
  static const metricSm = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Upper-case Latin labels (PACE, BPM, GPS). Never for Thai strings.
  static const monoLabel = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
  );
  static const monoLabelSm = TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _fallback,
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textMuted,
  );

  // Copy (Prompt). Line heights ≥ 1.45 keep Thai tone marks unclipped.
  static const headlineLg = TextStyle(
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const headlineMd = TextStyle(
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const headlineSm = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const bodyLg = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.55,
    color: AppColors.textSecondary,
  );

  /// Small Thai label above a metric.
  static const label = TextStyle(
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.45,
    color: AppColors.textMuted,
  );
}
