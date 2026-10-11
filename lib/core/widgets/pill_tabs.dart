import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Segmented control: a lime thumb glides under the selected segment.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
    this.height = 44,
    this.mono = false,
  });

  final List<T> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final double height;

  /// Labels in JetBrains Mono (ratios such as 4:5).
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final index = items.indexOf(selected).clamp(0, items.length - 1);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: height + 8,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.lime,
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: AppColors.lime.withValues(alpha: 0.30),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: _Segment(
                        label: labelOf(item),
                        icon: iconOf?.call(item),
                        selected: item == selected,
                        mono: mono,
                        onTap: () {
                          if (item == selected) return;
                          HapticFeedback.selectionClick();
                          onChanged(item);
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.mono,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool mono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onLime : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: mono ? 'JetBrainsMono' : 'Prompt',
                      fontFamilyFallback: const ['Prompt'],
                      fontSize: mono ? 16 : 14,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
