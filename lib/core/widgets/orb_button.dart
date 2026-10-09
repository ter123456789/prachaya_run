import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The glowing glass bubble in the centre of the bottom bar.
class OrbButton extends StatefulWidget {
  const OrbButton({
    super.key,
    required this.onPressed,
    this.size = 60,
    this.active = false,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final double size;

  /// Pulses while a recording is running.
  final bool active;
  final String? tooltip;

  @override
  State<OrbButton> createState() => _OrbButtonState();
}

class _OrbButtonState extends State<OrbButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(OrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orb = GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (widget.active ? AppColors.lime : AppColors.glowTop)
                    .withValues(alpha: 0.35 + 0.35 * _pulse.value),
                blurRadius: 24 + 16 * _pulse.value,
                spreadRadius: 1 + 4 * _pulse.value,
              ),
            ],
            gradient: const RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 0.95,
              colors: [
                Colors.white,
                Color(0xFFE3F4EE),
                Color(0xFF9CC9D6),
                Color(0xFF5C8C7A),
                Color(0xFFCFE59B),
              ],
              stops: [0, 0.18, 0.55, 0.85, 1],
            ),
          ),
          child: child,
        ),
        child: Icon(
          widget.active ? Icons.graphic_eq : Icons.play_arrow_rounded,
          color: const Color(0xCC1B2A24),
          size: widget.size * 0.4,
        ),
      ),
    );
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: widget.tooltip == null
          ? orb
          : Tooltip(message: widget.tooltip, child: orb),
    );
  }
}
