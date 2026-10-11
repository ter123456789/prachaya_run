import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'circle_icon_button.dart';
import 'pressable.dart';
import 'status_pill.dart';

/// Screen header: back button or a live mint dot, title, trailing actions.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.dot = true,
  });

  final String title;

  /// Shows a back button instead of the dot.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (onBack != null) ...[
            CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'กลับ',
              size: 44,
              onPressed: onBack,
            ),
            const SizedBox(width: 12),
          ] else if (dot) ...[
            const PulseDot(color: AppColors.mint, size: 10),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: AppText.headlineMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// White circular avatar button (account). A lime dot marks a signed-in,
/// synced account.
class AvatarButton extends StatelessWidget {
  const AvatarButton({
    super.key,
    required this.onPressed,
    this.signedIn = false,
    this.size = 44,
  });

  final VoidCallback onPressed;
  final bool signedIn;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'บัญชี',
      child: Semantics(
        button: true,
        label: 'บัญชี',
        child: Pressable(
          onTap: onPressed,
          scale: 0.92,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.onLime,
                    size: size * 0.5,
                  ),
                ),
                if (signedIn)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: size * 0.3,
                      height: size * 0.3,
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + title row with an optional trailing action, for section starts.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.icon, this.action});

  final String title;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.lime, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(title, style: AppText.headlineSm)),
        ?action,
      ],
    );
  }
}
