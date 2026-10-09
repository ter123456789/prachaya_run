import 'package:flutter/material.dart';

/// Design tokens: near-black canvas, lime accent, frosted-glass surfaces.
abstract final class AppColors {
  static const background = Color(0xFF0C0D0B);
  static const surface = Color(0xFF161714);
  static const lime = Color(0xFFD4F36B);
  static const onLime = Color(0xFF11130C);

  /// Top-of-screen glow.
  static const glowTop = Color(0xFFC7DC8C);
  static const glowMid = Color(0xFF5E7A24);

  static const glassFill = Color(0x0FFFFFFF); // white 6%
  static const glassFillStrong = Color(0x1AFFFFFF); // white 10%
  static const glassBorder = Color(0x1FFFFFFF); // white 12%

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xB3FFFFFF); // white 70%
  static const textMuted = Color(0x80FFFFFF); // white 50%

  static const positive = Color(0xFFB8E35A);
  static const negative = Color(0xFFF2A65A);
}
