import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/glass_card.dart';
import '../bloc/routes_cubit.dart';
import '../pages/route_list_page.dart';

/// Way into the route builder from the schedule.
class RoutesTeaser extends StatelessWidget {
  const RoutesTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select((RoutesCubit c) => c.state.routes.length);
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(RouteListPage.route()),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gesture_rounded, color: AppColors.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('เส้นทางวิ่งจากรูปวาด', style: AppText.headlineSm),
                Text(
                  count == 0
                      ? 'วาดรูปบนแผนที่ ระบบหาเส้นทางวิ่งให้'
                      : 'บันทึกไว้ $count เส้นทาง',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
