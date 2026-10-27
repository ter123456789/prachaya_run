import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/content_width.dart';
import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../auth/presentation/pages/account_page.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/services/activity_sync.dart';
import '../../domain/services/calories.dart';
import '../../../athlete/presentation/units.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/history/history_cubit.dart';
import '../bloc/sync/sync_cubit.dart';
import '../widgets/origin_tag.dart';
import 'activity_detail_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select(
      (AuthCubit c) => c.state.status == AuthStatus.signedIn,
    );
    return GlowBackground(
      glowHeight: 220,
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, state) {
            final months = MonthlySummary.group(state.visible);
            return ContentWidth(
              builder: (context, gutters) => Column(
                children: [
                  Padding(
                    padding: gutters.copyWith(top: 4),
                    child: AppTopBar(
                      title: 'ประวัติกิจกรรม',
                      actions: [
                        AvatarButton(
                          signedIn: signedIn,
                          onPressed: () =>
                              Navigator.of(context).push(AccountPage.route()),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: gutters.copyWith(top: 12, bottom: 8),
                    child: PillTabs<ActivityType?>(
                      items: const [null, ...ActivityType.values],
                      selected: state.filter,
                      labelOf: (t) => t?.label ?? 'ทั้งหมด',
                      iconOf: (t) => t?.icon ?? Icons.apps_rounded,
                      onChanged: context.read<HistoryCubit>().setFilter,
                    ),
                  ),
                  Expanded(
                    child: EdgeFade(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey((state.filter, state.status)),
                          child: _body(context, state, months, gutters),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    HistoryState state,
    List<MonthlySummary> months,
    EdgeInsets gutters,
  ) {
    if (months.isEmpty) {
      return switch (state.status) {
        HistoryStatus.loading => ListView(
          padding: gutters.copyWith(top: 8),
          children: const [
            Shimmer(height: 150, radius: 28),
            SizedBox(height: 14),
            Shimmer(height: 160, radius: 28),
            SizedBox(height: 14),
            Shimmer(height: 160, radius: 28),
          ],
        ),
        HistoryStatus.failure => const Center(
          child: Text('โหลดข้อมูลไม่สำเร็จ', style: AppText.body),
        ),
        HistoryStatus.loaded => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_run_rounded,
                  color: AppColors.lime,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text('ยังไม่มีกิจกรรม ออกไปวิ่งกัน!', style: AppText.body),
            ],
          ),
        ),
      };
    }
    var index = 0;
    return RefreshIndicator(
      color: AppColors.onLime,
      backgroundColor: AppColors.lime,
      onRefresh: context.syncActivities,
      child: ListView(
        padding: gutters.copyWith(top: 8, bottom: 150),
        children: [
          for (final month in months) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 40 * (index++).clamp(0, 8)),
              child: _MonthCard(month),
            ),
            const SizedBox(height: 14),
            for (final a in month.activities) ...[
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * (index++).clamp(0, 8)),
                child: _ActivityCard(a),
              ),
              const SizedBox(height: 14),
            ],
          ],
          const Center(child: _SyncBadge()),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard(this.month);

  final MonthlySummary month;

  @override
  Widget build(BuildContext context) {
    final weight = context.select((ProfileCubit c) => c.state.weightKg);
    final kcal = month.activities.fold<double>(
      0,
      (s, a) =>
          s +
          estimateCalories(
            type: a.type,
            distanceMeters: a.distanceMeters,
            movingTime: a.movingTime,
            weightKg: weight,
          ),
    );
    final hours = month.movingTime.inHours;
    final minutes = month.movingTime.inMinutes.remainder(60);
    return GlassCard(
      radius: 28,
      strong: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const PulseDot(color: AppColors.lime, size: 9),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatMonthYear(month.month),
                  style: AppText.headlineMd,
                ),
              ),
              StatusPill(text: '${month.count} กิจกรรม', color: AppColors.lime),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MonthStat(
                label: 'ระยะทางรวม',
                value: context.units
                    .distanceValue(month.distanceMeters)
                    .toStringAsFixed(1),
                unit: context.units.distanceUnit,
              ),
              const SizedBox(width: 8),
              _MonthStat(
                label: 'เวลารวม',
                value: '$hours:${minutes.toString().padLeft(2, '0')}',
                unit: 'ชม.',
              ),
              const SizedBox(width: 8),
              _MonthStat(
                label: 'แคลอรี่',
                value: _thousands(kcal.round()),
                unit: 'kcal',
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            FittedBox(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppText.metricMd.copyWith(color: color),
                    ),
                    TextSpan(text: ' $unit', style: AppText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(this.summary);

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final speed = summary.averageSpeedMps;
    final hike = summary.type == ActivityType.hike;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.of(context).push(ActivityDetailPage.route(summary.id));
        if (context.mounted) await context.refreshActivities();
      },
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: hike
                      ? AppColors.secondary.withValues(alpha: 0.16)
                      : AppColors.limeSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  summary.type.icon,
                  color: hike ? AppColors.secondary : AppColors.lime,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTitle(
                        summary.title,
                        summary.type,
                        summary.startedAt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineSm,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formatDateTime(summary.startedAt),
                            style: AppText.monoLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (summary.origin.label case final from?) ...[
                          const SizedBox(width: 8),
                          Flexible(child: OriginTag(from)),
                        ],
                      ],
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _Metric(
                  icon: Icons.speed_rounded,
                  label: summary.type.usesPace ? 'เพซ' : 'ความเร็ว',
                  value: summary.type.usesPace
                      ? context.units.pace(speed)
                      : context.units.speed(speed),
                  unit: summary.type.usesPace
                      ? context.units.paceUnit
                      : context.units.speedUnit,
                ),
                _Metric(
                  icon: Icons.route_rounded,
                  label: 'ระยะทาง',
                  value: context.units.distance(summary.distanceMeters),
                  unit: context.units.distanceUnit,
                ),
                _Metric(
                  icon: Icons.timer_outlined,
                  label: 'เวลา',
                  value: formatDuration(summary.movingTime),
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
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.lime),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: AppText.metricMd),
                  if (unit != null)
                    TextSpan(text: ' $unit', style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select(
      (AuthCubit c) => c.state.status == AuthStatus.signedIn,
    );
    final sync = context.watch<SyncCubit>().state;
    final (icon, text, color) = !signedIn
        ? (
            Icons.phone_iphone_rounded,
            'บันทึกในเครื่อง · เข้าสู่ระบบเพื่อซิงก์',
            AppColors.textSecondary,
          )
        : sync.syncing
        ? (Icons.sync_rounded, 'กำลังซิงก์…', AppColors.textSecondary)
        : sync.lastOutcome == SyncOutcome.offline
        ? (
            Icons.cloud_off_outlined,
            'ออฟไลน์ · จะซิงก์เมื่อต่อเน็ตได้',
            AppColors.negative,
          )
        : (
            Icons.verified_outlined,
            'ข้อมูลทั้งหมดซิงค์กับคลาวด์แล้ว',
            AppColors.secondary,
          );
    return StatusPill(text: text, icon: icon, color: color);
  }
}
