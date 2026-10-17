import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/layout/content_width.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/bento_stat.dart';
import '../../../../core/widgets/count_up_text.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_insights.dart';
import '../../domain/entities/monthly_challenge.dart';
import '../../domain/entities/route_shape.dart';
import '../../domain/entities/weather_report.dart';
import '../../domain/entities/weekly_stats.dart';
import '../../domain/services/calories.dart';
import '../../../../core/units/unit_labels.dart';
import '../../../athlete/presentation/pages/profile_page.dart';
import '../../../athlete/presentation/units.dart';
import '../../../training/presentation/pages/schedule_page.dart';
import '../../../training/presentation/widgets/training_teaser.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/dashboard/dashboard_cubit.dart';
import '../bloc/record/record_bloc.dart';
import '../widgets/route_canvas.dart';
import 'activity_detail_page.dart';

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
    final signedIn = context.select(
      (AuthCubit c) => c.state.status == AuthStatus.signedIn,
    );
    return GlowBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return EdgeFade(
              child: RefreshIndicator(
                color: AppColors.onLime,
                backgroundColor: AppColors.lime,
                onRefresh: context.syncActivities,
                child: AdaptiveColumns(
                  bottom: 140,
                  header: [
                    AppTopBar(
                      title: 'หน้าหลัก',
                      actions: [
                        AvatarButton(
                          signedIn: signedIn,
                          onPressed: () =>
                              Navigator.of(context).push(ProfilePage.route()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(child: _Greeting(now: now)),
                    _RecordingBanner(onTap: onStart),
                    const SizedBox(height: 24),
                  ],
                  start: [
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: SectionHeader(
                        'ความคืบหน้าสัปดาห์นี้',
                        icon: Icons.show_chart_rounded,
                        action: state.week == null
                            ? null
                            : StatusPill(
                                text: 'สัปดาห์ที่ ${state.week!.weekNumber}',
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: _WeekBento(week: state.week),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: state.weather == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: FadeSlideIn(
                                child: _WeatherCard(state.weather!, now: now),
                              ),
                            ),
                    ),
                  ],
                  end: [
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: SectionHeader(
                        'กิจกรรมล่าสุด',
                        icon: Icons.history_rounded,
                        action: TextButton.icon(
                          onPressed: onSeeAll,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: const Text('ดูทั้งหมด'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
                      child: _LatestActivity(
                        activity: state.latest,
                        insights: state.latestInsights,
                        now: now,
                        onStart: onStart,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: SectionHeader(
                        'ตารางซ้อม',
                        icon: Icons.event_note_outlined,
                        action: TextButton.icon(
                          onPressed: () =>
                              Navigator.of(context).push(SchedulePage.route()),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: const Text('ดูตาราง'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 320),
                      child: TrainingTeaser(),
                    ),
                    if (state.challenge != null) ...[
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 320),
                        child: _ChallengeCard(
                          challenge: state.challenge!,
                          meters: state.challengeMeters,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final name = context.select(
      (ProfileCubit c) => c.state.profile.displayName,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PulseDot(color: AppColors.lime, size: 7),
            const SizedBox(width: 8),
            Text(
              'สวัสดี${timeOfDayPeriod(now)}${name == null ? '' : ' $name'}',
              style: AppText.label,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('พร้อมออกไปวิ่งหรือยัง?', style: AppText.headlineLg),
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
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: !state.isActive
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: GlassCard(
                    strong: true,
                    onTap: onTap,
                    child: Row(
                      children: [
                        PulseDot(
                          color: state.status == RecordStatus.paused
                              ? AppColors.negative
                              : AppColors.lime,
                          size: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${state.status == RecordStatus.paused ? 'หยุดชั่วคราว' : 'กำลังบันทึก'}'
                            '${state.type.label}',
                          ),
                        ),
                        Text(
                          '${formatDuration(state.movingTime)} · '
                          '${context.units.distance(state.distanceMeters)} '
                          '${context.units.distanceUnit}',
                          style: AppText.metricSm,
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _WeekBento extends StatelessWidget {
  const _WeekBento({required this.week});

  final WeeklyStats? week;

  @override
  Widget build(BuildContext context) {
    final w = week;
    final distance = w?.distanceMeters ?? 0;
    final progress = w?.progressToward(kWeeklyGoalMeters) ?? 0;
    final today = w?.todayDistanceMeters ?? 0;
    final time = w?.movingTime ?? Duration.zero;
    final units = context.units;
    final goal = units.distanceValue(kWeeklyGoalMeters);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GlassCard(
                  radius: 24,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เป้าหมายรายสัปดาห์', style: AppText.label),
                      const SizedBox(height: 12),
                      Center(
                        child: ProgressRing(
                          progress: progress,
                          size: 120,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CountUpText(
                                progress * 100,
                                format: (v) => '${v.round()}%',
                                style: AppText.metricLg,
                              ),
                              const Text(
                                'COMPLETED',
                                style: AppText.monoLabelSm,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FittedBox(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: units.distance(distance),
                                    style: AppText.metricSm,
                                  ),
                                  TextSpan(
                                    text:
                                        ' จาก ${goal == goal.roundToDouble() ? goal.round() : goal.toStringAsFixed(1)} '
                                        '${units.distanceUnit}',
                                    style: AppText.label,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    BentoStat(
                      label: 'ระยะทาง',
                      icon: Icons.route_rounded,
                      value: units.distance(distance),
                      numeric: units.distanceValue(distance),
                      format: (v) => v.toStringAsFixed(2),
                      unit: units.distanceUnit,
                      footer: today > 0
                          ? '+${units.distance(today)} วันนี้'
                          : 'ยังไม่ได้ออกวันนี้',
                      footerIcon: today > 0 ? Icons.trending_up_rounded : null,
                      footerColor: today > 0 ? AppColors.lime : null,
                    ),
                    const SizedBox(height: 12),
                    BentoStat(
                      label: 'ขึ้นสะสม',
                      icon: Icons.landscape_outlined,
                      value: '${(w?.elevationGainMeters ?? 0).round()}',
                      numeric: w?.elevationGainMeters ?? 0,
                      format: (v) => '${v.round()}',
                      unit: 'ม.',
                      footer:
                          'ทางชันเฉลี่ย ${(w?.averageGradePercent ?? 0).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BentoStat(
                label: 'เวลา',
                icon: Icons.timer_outlined,
                value: formatDuration(time),
                numeric: time.inSeconds.toDouble(),
                format: (v) => formatDuration(Duration(seconds: v.round())),
                footer: time.inHours > 0
                    ? 'ชั่วโมง:นาที:วินาที'
                    : 'นาที:วินาที',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoStat(
                label: 'กิจกรรม',
                icon: Icons.flag_outlined,
                value: '${w?.activityCount ?? 0}',
                numeric: (w?.activityCount ?? 0).toDouble(),
                format: (v) => '${v.round()}',
                unit: 'ครั้ง',
                footer: 'สัปดาห์ปัจจุบัน',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard(this.weather, {required this.now});

  final WeatherReport weather;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final advice = adviseRun(weather);
    final when = now.hour >= 17 || now.hour < 5 ? 'คืนนี้' : 'ตอนนี้';
    return GlassCard(
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
              advice == RunAdvice.great ? Icons.bolt_rounded : weather.icon,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$when${weather.description} ${weather.temperatureLabel}',
                  style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  'ลม ${context.units.windFromKmh(weather.windKmh)} · '
                  '${advice.hint}',
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                ),
              ],
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
    required this.insights,
    required this.now,
    required this.onStart,
  });

  final Activity? activity;
  final ActivityInsights? insights;
  final DateTime now;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    if (a == null) {
      return GlassCard(
        onTap: onStart,
        padding: const EdgeInsets.all(28),
        child: const Column(
          children: [
            Icon(Icons.directions_run_rounded, color: AppColors.lime, size: 40),
            SizedBox(height: 10),
            Text('ยังไม่มีกิจกรรม', style: AppText.headlineSm),
            SizedBox(height: 2),
            Text('แตะปุ่มกลมตรงกลางเพื่อเริ่มบันทึก', style: AppText.body),
          ],
        ),
      );
    }
    final weight = context.select((ProfileCubit c) => c.state.weightKg);
    final speed = a.summary.averageSpeedMps;
    final kcal = estimateCalories(
      type: a.type,
      distanceMeters: a.distanceMeters,
      movingTime: a.movingTime,
      weightKg: weight,
    );
    final effort = insights?.effort;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.of(context).push(ActivityDetailPage.route(a.id));
        if (context.mounted) await context.refreshActivities();
      },
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 210,
              color: AppColors.background,
              child: Stack(
                children: [
                  // Keep the route clear of the badge row on top.
                  Positioned.fill(
                    top: 44,
                    child: RouteCanvas(
                      shape: RouteShape.fromSegments(a.segments),
                      padding: 0.1,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: StatusPill(
                      text: a.type.label,
                      dotColor: AppColors.mint,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: StatusPill(
                      text: a.type.usesPace
                          ? 'PACE ${context.units.paceQuote(speed)}'
                          : '${context.units.speed(speed)} '
                                '${context.units.unit.latinSpeed}',
                      mono: true,
                      color: AppColors.lime,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.limeSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(a.type.icon, color: AppColors.lime, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.title,
                              style: AppText.headlineSm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (effort != null) ...[
                            const SizedBox(width: 8),
                            _Tag(effort.tag(a.type)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: context.units.distance(a.distanceMeters),
                              style: AppText.metricSm,
                            ),
                            TextSpan(
                              text: ' ${context.units.distanceUnit}  •  ',
                            ),
                            TextSpan(
                              text: formatDurationShort(a.movingTime),
                              style: AppText.metricSm,
                            ),
                          ],
                        ),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                StatusPill(text: formatRelative(a.endedAt, now)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                label: a.type.usesPace ? 'เพซเฉลี่ย' : 'ความเร็วเฉลี่ย',
                value: a.type.usesPace
                    ? context.units.paceQuote(speed)
                    : '${context.units.speed(speed)} '
                          '${context.units.speedUnit}',
              ),
              _MiniStat(label: 'แคลอรี่', value: '${kcal.round()} kcal'),
              _MiniStat(
                label: 'ขึ้นสะสม',
                value: '${a.elevationGainMeters.round()} ม.',
                color: AppColors.lime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.secondary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: AppText.monoLabel.copyWith(color: AppColors.secondary),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                value,
                style: AppText.metricSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.challenge, required this.meters});

  final MonthlyChallenge challenge;
  final double meters;

  @override
  Widget build(BuildContext context) {
    final progress = (meters / challenge.goalMeters).clamp(0.0, 1.0);
    final left = (challenge.goalMeters - meters).clamp(0, double.infinity);
    final done = left <= 0;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.emoji_events_rounded : Icons.military_tech_outlined,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  done
                      ? 'สำเร็จแล้ว! ได้รับเหรียญ ${challenge.badge}'
                      : 'สะสมอีก ${context.units.distance(left.toDouble())} '
                            '${context.units.distanceUnit} '
                            'เพื่อรับเหรียญ ${challenge.badge}',
                  style: AppText.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: AppColors.secondary,
                      backgroundColor: AppColors.surfaceHighest,
                    ),
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
