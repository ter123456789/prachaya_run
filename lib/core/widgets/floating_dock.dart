import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'orb_button.dart';

class DockItem {
  const DockItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating glass dock 16 px above the home indicator, with the mint orb
/// rising out of its centre. Exactly two items: left and right of the orb.
class FloatingDock extends StatelessWidget {
  const FloatingDock({
    super.key,
    required this.items,
    required this.index,
    required this.onTab,
    required this.onOrb,
    this.orbActive = false,
    this.orbTooltip,
  }) : assert(items.length == 2);

  final List<DockItem> items;
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onOrb;
  final bool orbActive;
  final String? orbTooltip;

  static const height = 64.0;

  /// Stays thumb-sized on wide screens (foldables, landscape).
  static const maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: height + 26,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: const Color(0xCC1B1C1A),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _tab(0)),
                            const SizedBox(width: 96),
                            Expanded(child: _tab(1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: OrbButton(
                      onPressed: onOrb,
                      active: orbActive,
                      tooltip: orbTooltip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final item = items[i];
    final selected = i == index;
    final color = selected ? AppColors.mint : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            onTab(i);
          },
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.1 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: const Duration(milliseconds: 220),
                  builder: (context, c, _) =>
                      Icon(item.icon, color: c, size: 24),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontFamily: 'Prompt',
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
