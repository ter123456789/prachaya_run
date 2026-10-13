import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../activity/domain/entities/activity_type.dart';
import '../../../activity/domain/entities/weather_report.dart';
import '../../../activity/presentation/activity_labels.dart';
import '../../../activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import '../../../activity/presentation/bloc/record/record_bloc.dart';
import '../../../activity/presentation/pages/activity_detail_page.dart';
import '../../../activity/presentation/pages/record_page.dart';
import '../../../athlete/presentation/units.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/widgets/guest_widgets.dart';
import '../../domain/entities/planned_workout.dart';
import '../../domain/services/workout_plan.dart';
import '../bloc/training_cubit.dart';
import '../training_labels.dart';
import '../widgets/workout_sheet.dart';

/// Stitch 09 "กำหนดการวิ่ง & ตารางซ้อม": the week strip, the chosen day's
/// session, current weather, this week's progress and what comes next.
///
/// Left out on purpose: multi-week plan names (e.g. "Half-Marathon Sub 2")
/// and best-time windows — the app has no data for them.
///
/// Signed out (Stitch 09 guest) the planner works the same; a pass card at
/// the end invites to sign up so the plans sync across devices.
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  /// [day] opens on that day (a reminder was tapped).
  static Route<void> route({DateTime? day}) => MaterialPageRoute(
    builder: (context) {
      if (day != null) context.read<TrainingCubit>().selectDay(day);
      return const SchedulePage();
    },
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingCubit>().state;
    final signedOut = context.select(
      (AuthCubit c) => c.state.status == AuthStatus.signedOut,
    );
    final weather = context.select((DashboardCubit c) => c.state.weather);
    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 60 * i++),
      child: child,
    );
    return Scaffold(
      body: GlowBackground(
        glowHeight: 240,
        child: SafeArea(
          bottom: false,
          child: EdgeFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                AppTopBar(
                  title: 'ตารางซ้อม',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 8),
                stagger(const _Title()),
                const SizedBox(height: 16),
                stagger(_WeekStrip(state: state)),
                const SizedBox(height: 16),
                stagger(_FocusCard(state: state)),
                if (weather != null) ...[
                  const SizedBox(height: 16),
                  stagger(_WeatherCard(weather)),
                ],
                const SizedBox(height: 16),
                stagger(_WeekProgress(week: state.week)),
                const SizedBox(height: 24),
                stagger(
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ตารางที่กำลังจะมาถึง',
                          style: AppText.headlineSm,
                        ),
                      ),
                      Text(
                        '${state.upcoming.length} เซสชัน',
                        style: AppText.monoLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (state.upcoming.isEmpty)
                  stagger(
                    const GlassCard(
                      child: Text(
                        'ยังไม่มีตารางล่วงหน้า กด "เพิ่มตาราง" เพื่อวางแผนวันถัดไป',
                        style: AppText.body,
                      ),
                    ),
                  )
                else
                  for (final w in state.upcoming)
                    stagger(_UpcomingTile(w, done: state.isDone(w))),
                if (signedOut) ...[
                  const SizedBox(height: 24),
                  stagger(const SchedulePassCard()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRAINING HUB',
                style: AppText.monoLabel.copyWith(color: AppColors.secondary),
              ),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'กำหนดการวิ่ง & ตารางซ้อม',
                  style: AppText.headlineLg,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => WorkoutSheet.show(context),
          icon: const Icon(Icons.add_rounded, color: AppColors.lime),
          label: const Text('เพิ่มตาราง'),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.state});

  final TrainingState state;

  @override
  Widget build(BuildContext context) {
    final week = state.week;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'สัปดาห์ปัจจุบัน (${week.start.day} - '
                '${formatDayMonth(week.end)})',
                style: AppText.label,
              ),
            ),
            StatusPill(
              text: 'WEEK ${week.weekNumber}',
              mono: true,
              color: AppColors.lime,
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              for (final day in week.days)
                Expanded(
                  child: _DayCell(
                    day: day,
                    selected: isSameDay(day.date, state.selectedDay),
                    today: isSameDay(day.date, state.today),
                    upcoming: day.date.isAfter(state.today),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.upcoming,
  });

  final TrainingDay day;
  final bool selected;
  final bool today;

  /// Days still ahead get a mint dot, today and earlier a lime one.
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.lime : AppColors.textPrimary;
    final planned = day.workouts.any((w) => !w.isRest);
    return Semantics(
      button: true,
      selected: selected,
      label: formatLongDate(day.date),
      child: Pressable(
        onTap: () => context.read<TrainingCubit>().selectDay(day.date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            children: [
              Text(
                thaiWeekdayShort(day.date),
                style: AppText.caption.copyWith(
                  color: selected ? AppColors.lime : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.date.day}',
                style: AppText.metricMd.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 14,
                child: day.isRestDay
                    ? Text('พัก', style: AppText.caption.copyWith(fontSize: 10))
                    : planned
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: upcoming
                              ? AppColors.secondary
                              : AppColors.lime,
                        ),
                      )
                    : today
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceHighest,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.state});

  final TrainingState state;

  @override
  Widget build(BuildContext context) {
    final w = state.focus;
    final day = state.selectedDay;
    final isToday = isSameDay(day, state.today);
    final dayLabel = isToday
        ? 'เป้าหมายวันนี้'
        : 'เป้าหมาย ${thaiWeekdayShort(day)} ${day.day}';
    if (w == null) {
      return GlassCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(text: dayLabel, color: AppColors.lime),
            const SizedBox(height: 12),
            Text(
              isToday ? 'ยังไม่มีแผนสำหรับวันนี้' : 'ยังไม่มีแผนสำหรับวันนั้น',
              style: AppText.headlineSm,
            ),
            const SizedBox(height: 4),
            const Text(
              'วางแผนระยะ เพซ และช่วงการซ้อม แล้วแอปจะติ๊กให้เมื่อคุณวิ่งเสร็จ',
              style: AppText.body,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => WorkoutSheet.show(context, day: day),
              icon: const Icon(Icons.add_rounded),
              label: const Text('วางแผนซ้อม'),
            ),
          ],
        ),
      );
    }
    final units = context.units;
    final done = state.isDone(w);
    final zones = targetZones(w.type);
    final phases = workoutPhases(w);
    final estimate = estimatedDuration(w);
    return GlassCard(
      radius: 28,
      strong: true,
      padding: const EdgeInsets.all(18),
      onTap: () => WorkoutSheet.show(context, existing: w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                flex: 3,
                child: StatusPill(
                  text: dayLabel,
                  color: AppColors.onLime,
                  background: AppColors.lime,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text('${formatClock(w.scheduledAt)} น.', style: AppText.metricSm),
              const Spacer(),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(w.type.icon, color: AppColors.lime),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(w.title, style: AppText.headlineMd),
          if (w.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w.location!,
                      style: AppText.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (w.isRest) ...[
            const SizedBox(height: 12),
            const Text(
              'วันพักกล้ามเนื้อ ยืดเหยียดและนอนให้พอ ร่างกายจะพร้อมสำหรับวันถัดไป',
              style: AppText.body,
            ),
          ] else ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Target(
                    label: 'ระยะทางเป้าหมาย',
                    value: units.distance(w.distanceMeters),
                    unit: units.distanceUnit,
                    footer: zones == null
                        ? null
                        : 'โซนความเร็ว ${zones.$1}${zones.$1 == zones.$2 ? '' : '-${zones.$2}'}',
                    footerIcon: Icons.flag_outlined,
                    valueColor: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 10),
                  _Target(
                    label: 'เพซเป้าหมาย (PACE)',
                    value: paceRange(units, w),
                    footer: estimate == null
                        ? null
                        : 'ใช้เวลาราว ${formatDuration(estimate)}',
                    footerIcon: Icons.timer_outlined,
                  ),
                ],
              ),
            ),
            if (phases.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_outlined,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phaseSummary(units, phases),
                        style: AppText.label,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (done)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(ActivityDetailPage.route(w.completedActivityId!)),
                icon: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.secondary,
                ),
                label: const Text('ซ้อมสำเร็จแล้ว ดูกิจกรรม'),
              )
            else if (isToday)
              FilledButton(
                onPressed: () => _start(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'เริ่มวิ่งตามแผนนี้เลย',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Opens the recorder set to a run (the run ticks this session off when
  /// it is saved).
  void _start(BuildContext context) {
    final record = context.read<RecordBloc>();
    if (!record.state.isActive) {
      record.add(const RecordTypeChanged(ActivityType.run));
    }
    Navigator.of(context).push(RecordPage.route());
  }
}

class _Target extends StatelessWidget {
  const _Target({
    required this.label,
    required this.value,
    this.unit,
    this.footer,
    this.footerIcon,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final String? footer;
  final IconData? footerIcon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.label),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppText.metricLg.copyWith(color: valueColor),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(unit!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const Spacer(),
            if (footer != null)
              Row(
                children: [
                  Icon(footerIcon, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      footer!,
                      style: AppText.caption.copyWith(
                        color: AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard(this.weather);

  final WeatherReport weather;

  @override
  Widget build(BuildContext context) {
    final advice = adviseRun(weather);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(weather.icon, color: AppColors.lime),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'สภาพอากาศสำหรับวิ่งตอนนี้',
                        style: AppText.headlineSm,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PulseDot(
                      color: advice == RunAdvice.great
                          ? AppColors.secondary
                          : AppColors.negative,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${weather.description} ${weather.temperatureLabel} · '
                  'ลม ${context.units.windFromKmh(weather.windKmh)} '
                  '${advice.headline} ${advice.hint}',
                  style: AppText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekProgress extends StatelessWidget {
  const _WeekProgress({required this.week});

  final TrainingWeek week;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('แผนซ้อมสัปดาห์นี้', style: AppText.headlineSm),
                    Text(
                      'สัปดาห์ที่ ${week.weekNumber} • '
                      '${formatDayMonth(week.start)} - ${formatDayMonth(week.end)}',
                      style: AppText.monoLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'ความถี่สัปดาห์นี้: ',
                          style: AppText.label,
                        ),
                        TextSpan(
                          text:
                              '${week.completedSessions} / ${week.plannedSessions} ครั้ง',
                          style: AppText.metricSm,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'ระยะสะสม: ', style: AppText.label),
                      TextSpan(
                        text: planDistance(units, week.completedMeters),
                        style: AppText.metricSm.copyWith(color: AppColors.lime),
                      ),
                      TextSpan(
                        text:
                            ' / ${planDistance(units, week.plannedMeters)} '
                            '${units.distanceUnit}',
                        style: AppText.metricSm,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: week.progress),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: AppColors.surfaceHighest),
                    ),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.lime, AppColors.mint],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('ความคืบหน้ารวมรอบสัปดาห์', style: AppText.caption),
              ),
              Text(
                '${(week.progress * 100).round()}%',
                style: AppText.metricSm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile(this.workout, {required this.done});

  final PlannedWorkout workout;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final w = workout;
    final zones = targetZones(w.type);
    final subtitle = w.isRest
        ? (w.location ?? 'ยืดเหยียดและพักผ่อน')
        : [
            '${planDistance(units, w.distanceMeters)} ${units.distanceUnit}',
            if (zones != null) zonesLabel(zones.$1, zones.$2),
            if (w.paceMinSecPerKm != null) 'เพซ ${paceRange(units, w)}',
          ].join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(14),
        onTap: () => WorkoutSheet.show(context, existing: w),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    thaiWeekday(w.scheduledAt),
                    style: AppText.caption.copyWith(fontSize: 10),
                  ),
                  Text(
                    '${w.scheduledAt.day}',
                    style: AppText.metricSm.copyWith(color: AppColors.lime),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppText.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (w.isRest)
              const StatusPill(text: 'พักผ่อน')
            else if (done)
              const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
