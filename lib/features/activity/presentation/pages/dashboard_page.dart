import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_stat_tile.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/route_shape.dart';
import '../../domain/entities/weekly_stats.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/dashboard/dashboard_cubit.dart';
import '../bloc/record/record_bloc.dart';
import '../widgets/route_painter.dart';
import 'activity_detail_page.dart';

/// Weekly distance goal shown on the ring. Fixed for now.
const double kWeeklyGoalMeters = 20000;

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onSeeAll,
    required this.onStart,
  });

  final VoidCallback onSeeAll;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: context.refreshActivities,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                children: [
                  // Sections rise in one after another on first show.
                  FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สวัสดี${timeOfDayPeriod(now)}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'พร้อมออกไปวิ่งหรือยัง?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RecordingBanner(onTap: onStart),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('ความคืบหน้าสัปดาห์นี้'),
                        const SizedBox(height: 12),
                        _ProgressGrid(week: state.week),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(
                          'กิจกรรมล่าสุด',
                          action: TextButton(
                            onPressed: onSeeAll,
                            child: const Text('ดูทั้งหมด'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LatestActivity(
                          activity: state.latest,
                          now: now,
                          onStart: onStart,
                        ),
                      ],
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
          ),
        ),
        ?action,
      ],
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordBloc, RecordState>(
      buildWhen: (p, c) =>
          p.isActive != c.isActive ||
          p.movingTime.inSeconds != c.movingTime.inSeconds ||
          p.status != c.status,
      builder: (context, state) {
        if (!state.isActive) return const SizedBox.shrink();
        final paused = state.status == RecordStatus.paused;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GlassCard(
            strong: true,
            onTap: onTap,
            child: Row(
              children: [
                Icon(
                  paused ? Icons.pause_circle : Icons.fiber_manual_record,
                  color: AppColors.lime,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${paused ? 'หยุดชั่วคราว' : 'กำลังบันทึก'}${state.type.label}'
                    ' · ${formatDuration(state.movingTime)}'
                    ' · ${formatDistanceKm(state.distanceMeters)} กม.',
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressGrid extends StatelessWidget {
  const _ProgressGrid({required this.week});

  final WeeklyStats? week;

  @override
  Widget build(BuildContext context) {
    final w = week;
    final change = w?.distanceChangeMeters ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _GoalRingCard(week: w),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GlassStatTile(
                      icon: Icons.timer_outlined,
                      label: 'เวลา',
                      value: formatDuration(w?.movingTime ?? Duration.zero),
                      valueSize: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassStatTile(
                      icon: Icons.flag_outlined,
                      label: 'กิจกรรม',
                      value: '${w?.activityCount ?? 0}',
                      unit: 'ครั้ง',
                      valueSize: 17,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassStatTile(
                icon: Icons.route,
                label: 'ระยะทาง',
                value: formatDistanceKm(w?.distanceMeters ?? 0),
                unit: 'กม.',
                footer: w == null || w.previousWeekDistanceMeters == 0
                    ? null
                    : _Delta(change),
              ),
              const SizedBox(height: 10),
              GlassStatTile(
                icon: Icons.terrain_outlined,
                label: 'ขึ้นสะสม',
                value: '${(w?.elevationGainMeters ?? 0).round()}',
                unit: 'ม.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta(this.meters);

  final double meters;

  @override
  Widget build(BuildContext context) {
    final up = meters >= 0;
    final color = up ? AppColors.positive : AppColors.negative;
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${up ? '+' : ''}${formatDistanceKm(meters)}',
                  style: TextStyle(color: color),
                ),
                const TextSpan(text: ' จากสัปดาห์ก่อน'),
              ],
            ),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GoalRingCard extends StatelessWidget {
  const _GoalRingCard({required this.week});

  final WeeklyStats? week;

  @override
  Widget build(BuildContext context) {
    final progress = week?.progressToward(kWeeklyGoalMeters) ?? 0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('เป้าหมายรายสัปดาห์', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Center(
            child: SizedBox.square(
              dimension: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.glassFillStrong,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${formatDistanceKm(week?.distanceMeters ?? 0)} จาก '
              '${formatDistanceKm(kWeeklyGoalMeters).replaceAll('.00', '')} กม.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestActivity extends StatelessWidget {
  const _LatestActivity({
    required this.activity,
    required this.now,
    required this.onStart,
  });

  final Activity? activity;
  final DateTime now;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    if (a == null) {
      return GlassCard(
        onTap: onStart,
        padding: const EdgeInsets.all(24),
        child: const Column(
          children: [
            Icon(Icons.directions_run, color: AppColors.lime, size: 36),
            SizedBox(height: 8),
            Text('ยังไม่มีกิจกรรม'),
            Text(
              'แตะปุ่มกลมตรงกลางเพื่อเริ่มบันทึก',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    final shape = RouteShape.fromSegments(a.segments);
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: () async {
        await Navigator.of(context).push(ActivityDetailPage.route(a.id));
        if (context.mounted) await context.refreshActivities();
      },
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 70,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: CustomPaint(
                  painter: RoutePainter(
                    shape: shape,
                    color: AppColors.lime,
                    strokeWidth: 3,
                    shadow: false,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: GlassCard(
                blur: true,
                strong: true,
                radius: 14,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(a.type.icon, color: AppColors.lime, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${formatDistanceKm(a.distanceMeters)} กม.',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRelative(a.endedAt, now),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
