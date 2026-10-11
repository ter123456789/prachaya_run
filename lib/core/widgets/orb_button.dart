import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// The mint kinetic orb floating over the bottom dock. Breathes while a
/// recording is running.
class OrbButton extends StatefulWidget {
  const OrbButton({
    super.key,
    required this.onPressed,
    this.size = 68,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
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
    final orb = Pressable(
      onTap: widget.onPressed,
      scale: 0.9,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.mintIce, AppColors.mint],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mint.withValues(
                  alpha: 0.40 + 0.30 * _pulse.value,
                ),
                blurRadius: 28 + 14 * _pulse.value,
                spreadRadius: 4 * _pulse.value,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: Icon(
            widget.active ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
            key: ValueKey(widget.active),
            color: AppColors.onLime,
            size: widget.size * 0.42,
          ),
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
