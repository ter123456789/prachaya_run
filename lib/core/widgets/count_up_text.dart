import 'package:flutter/material.dart';

/// Shows a number that rolls from its previous value (or 0 on first show)
/// to [value]. [format] turns the animated double into text.
class CountUpText extends StatelessWidget {
  const CountUpText(
    this.value, {
    super.key,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}
