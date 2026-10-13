import 'package:flutter/material.dart';

/// "Obsidian Kinetic" tokens: obsidian canvas, kinetic lime, mint orb,
/// frosted glass. No reds anywhere: warnings and destructive actions use
/// [negative] (amber) plus an icon and copy.
abstract final class AppColors {
  static const background = Color(0xFF0C0D0B);
  static const surface = Color(0xFF161714);
  static const surfaceLow = Color(0xFF1B1C1A);
  static const surfaceHigh = Color(0xFF292A28);
  static const surfaceHighest = Color(0xFF343532);

  /// Pure black: the Sign in with Apple button (Apple's black style).
  static const ink = Color(0xFF000000);

  static const lime = Color(0xFFD4F36B);
  static const onLime = Color(0xFF11130C);
  static const limeSoft = Color(0x26D4F36B); // lime 15%, selected chips

  /// Centre orb and secondary telemetry (calories, sync OK).
  static const mint = Color(0xFF6EE7B7);
  static const mintIce = Color(0xFFC2F0EA);
  static const secondary = Color(0xFF62DCAD);

  /// Top-of-screen atmospheric glow.
  static const glowTop = Color(0xFFC7DC8C);
  static const glowMid = Color(0xFF5E7A24);

  static const glassFill = Color(0x0FFFFFFF); // white 6%
  static const glassFillStrong = Color(0x1AFFFFFF); // white 10%
  static const glassBorder = Color(0x1FFFFFFF); // white 12%
  static const glassHighlight = Color(0x26FFFFFF); // white 15%, top rim

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xB3FFFFFF); // white 70%
  static const textMuted = Color(0x80FFFFFF); // white 50%

  static const positive = Color(0xFFB8E35A);
  static const negative = Color(0xFFF2A65A);
}
