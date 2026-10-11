import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Small rounded badge: glowing dot or icon + short text, e.g.
/// "● สวนลุมพินี", "PACE 5'01\"", "GPS แม่นยำ".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    this.icon,
    this.dotColor,
    this.color = AppColors.textSecondary,
    this.mono = false,
    this.background = const Color(0xB3161714),
    this.pulse = false,
  });

  final String text;
  final IconData? icon;
  final Color? dotColor;
  final Color color;
  final bool mono;
  final Color background;

  /// Breathing dot (live states).
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            pulse ? PulseDot(color: dotColor!) : _Dot(color: dotColor!),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: mono
                ? AppText.monoLabel.copyWith(color: color)
                : AppText.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
      ],
    ),
  );
}

/// Dot whose glow breathes; static when animations are off.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.3 + 0.5 * _c.value),
              blurRadius: 4 + 8 * _c.value,
              spreadRadius: 2 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}
