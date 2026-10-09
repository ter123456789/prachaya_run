import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_type.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/history/history_cubit.dart';
import 'activity_detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      glowHeight: 220,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            final items = state.visible;
            return Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'ประวัติกิจกรรม',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: PillTabs<ActivityType?>(
                    items: const [null, ...ActivityType.values],
                    selected: state.filter,
                    labelOf: (t) => t?.label ?? 'ทั้งหมด',
                    onChanged: context.read<HistoryCubit>().setFilter,
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: switch (state.status) {
                            HistoryStatus.loading =>
                              const CircularProgressIndicator(),
                            HistoryStatus.failure => const Text(
                              'โหลดข้อมูลไม่สำเร็จ',
                            ),
                            HistoryStatus.loaded => const Text(
                              'ยังไม่มีกิจกรรม ออกไปวิ่งกัน!',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: context.refreshActivities,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                            children: _withMonthHeaders(items),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<Widget> _withMonthHeaders(List<ActivitySummary> items) {
    final widgets = <Widget>[];
    String? currentMonth;
    for (final a in items) {
      final month = formatMonthYear(a.startedAt);
      if (month != currentMonth) {
        currentMonth = month;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 4 : 20, bottom: 10),
            child: Text(
              month,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ActivityRow(a),
        ),
      );
    }
    return widgets;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.summary);

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final speed = summary.averageSpeedMps;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.of(context).push(ActivityDetailPage.route(summary.id));
        if (context.mounted) await context.refreshActivities();
      },
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(summary.type.icon, color: AppColors.lime, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    _Metric(
                      Icons.speed,
                      summary.type.usesPace
                          ? '${formatPace(speed)} /กม.'
                          : '${formatSpeedKmh(speed)} กม./ชม.',
                    ),
                    _Metric(
                      Icons.route,
                      '${formatDistanceKm(summary.distanceMeters)} กม.',
                    ),
                    _Metric(
                      Icons.timer_outlined,
                      formatDuration(summary.movingTime),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatDateTime(summary.startedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.lime),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
