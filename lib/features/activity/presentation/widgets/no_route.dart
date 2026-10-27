import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';

/// In place of the route for an activity imported without one (treadmill,
/// or a watch app that shares no GPS).
class NoRoute extends StatelessWidget {
  const NoRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.watch_outlined, color: AppColors.textMuted, size: 36),
          SizedBox(height: 8),
          Text('ไม่มีเส้นทาง GPS', style: AppText.caption),
        ],
      ),
    );
  }
}
