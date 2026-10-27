import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_pill.dart';

/// "⌚ Samsung Health": an activity that came from a watch app. Shrinks
/// with an ellipsis; give it bounded width (Flexible / Expanded).
class OriginTag extends StatelessWidget {
  const OriginTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => StatusPill(
    text: label,
    icon: Icons.watch_outlined,
    color: AppColors.secondary,
  );
}
