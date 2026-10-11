import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'pressable.dart';

/// Filter / toggle chip: 36–44 px, radius 12 (or pill). Selected = lime rim,
/// lime-tinted fill, lime label; [solid] makes the selected state a full
/// lime fill (used for the share-studio stat toggles).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.solid = false,
    this.pill = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool solid;
  final bool pill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !selected
        ? AppColors.textSecondary
        : solid
        ? AppColors.onLime
        : AppColors.lime;
    final bg = !selected
        ? AppColors.glassFill
        : solid
        ? AppColors.lime
        : AppColors.limeSoft;
    final radius = BorderRadius.circular(pill ? 999 : 12);
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: pill ? 44 : 36,
          padding: EdgeInsets.symmetric(horizontal: pill ? 16 : 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(
              color: selected && !solid
                  ? AppColors.lime
                  : selected
                  ? Colors.transparent
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
