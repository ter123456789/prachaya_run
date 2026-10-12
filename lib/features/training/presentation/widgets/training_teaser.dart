import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../athlete/presentation/units.dart';
import '../bloc/training_cubit.dart';
import '../pages/schedule_page.dart';
import '../training_labels.dart';

/// Dashboard entry to the schedule: today's (or the next) session.
class TrainingTeaser extends StatelessWidget {
  const TrainingTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingCubit>().state;
    final units = context.units;
    final today = state.focus;
    final next = today == null && state.upcoming.isNotEmpty
        ? state.upcoming.first
        : null;
    final w = today ?? next;
    void open() => Navigator.of(context).push(SchedulePage.route());
    return GlassCard(
      onTap: open,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              w?.type.icon ?? Icons.event_note_outlined,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w == null
                      ? 'วางแผนการซ้อมสัปดาห์นี้'
                      : today != null
                      ? 'วันนี้ ${formatClock(w.scheduledAt)} น. · ${w.title}'
                      : '${thaiWeekday(w.scheduledAt)} · ${w.title}',
                  style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  w == null
                      ? 'กำหนดระยะ เพซ และวันซ้อมล่วงหน้า'
                      : w.isRest
                      ? 'วันพักฟื้นฟู'
                      : state.isDone(w)
                      ? 'ซ้อมสำเร็จแล้ว'
                      : '${planDistance(units, w.distanceMeters)} '
                            '${units.distanceUnit} • เพซ ${paceRange(units, w)}',
                  style: AppText.caption.copyWith(
                    color: w != null && state.isDone(w)
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
