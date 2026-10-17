import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/layout/content_width.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/bento_stat.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/edge_fade.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../photo_share/domain/services/photo_source.dart';
import '../../../photo_share/presentation/pages/photo_overlay_page.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/activity_insights.dart';
import '../../domain/entities/activity_photo.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/weather_report.dart';
import '../../domain/repositories/activity_photo_repository.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/services/calories.dart';
import '../../domain/services/weather_service.dart';
import '../../../../core/units/distance_unit.dart';
import '../../../../core/units/unit_labels.dart';
import '../../../athlete/presentation/bloc/gear_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/detail/activity_detail_cubit.dart';
import '../widgets/route_map.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key});

  static Route<void> route(String activityId) => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) => ActivityDetailCubit(
        context.read<ActivityRepository>(),
        activityId,
        photos: context.read<ActivityPhotoRepository>(),
        weather: context.read<WeatherService?>(),
      )..load(),
      child: const ActivityDetailPage(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityDetailCubit, ActivityDetailState>(
      listenWhen: (_, curr) => curr.status == ActivityDetailStatus.deleted,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) {
        return Scaffold(
          body: GlowBackground(
            glowHeight: 240,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (state.status) {
                  ActivityDetailStatus.loaded => EdgeFade(child: _Body(state)),
                  ActivityDetailStatus.notFound => const _Message(
                    'ไม่พบกิจกรรมนี้',
                  ),
                  ActivityDetailStatus.failure => const _Message(
                    'โหลดข้อมูลไม่สำเร็จ',
                  ),
                  _ => const _Loading(),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      builder: (context, gutters) => ListView(
        padding: gutters.copyWith(top: 4),
        children: [
          AppTopBar(
            title: 'รายละเอียดกิจกรรม',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 16),
          const Shimmer(height: 300, radius: 28),
          const SizedBox(height: 20),
          const Shimmer(height: 28, width: 200),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Shimmer(height: 110, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: Shimmer(height: 110, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: Shimmer(height: 110, radius: 20)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return MaxWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            AppTopBar(
              title: 'รายละเอียดกิจกรรม',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(child: Text(text, style: AppText.body)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.state);

  final ActivityDetailState state;

  @override
  Widget build(BuildContext context) {
    final activity = state.activity!;
    final insights = state.insights!;
    final units = context.units;
    final splits = activity.type.usesPace
        ? activity.splits(every: units.unit.meters)
        : const <ActivitySplit>[];
    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 60 * (i++).clamp(0, 8)),
      child: child,
    );
    return AdaptiveColumns(
      gap: 16,
      header: [
        AppTopBar(
          title: 'รายละเอียดกิจกรรม',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 8),
        stagger(
          Row(
            children: [
              StatusPill(
                text: _typeTag(activity.type),
                icon: activity.type.icon,
                color: AppColors.lime,
                mono: true,
              ),
              const Spacer(),
              CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'แชร์',
                size: 44,
                onPressed: () => Navigator.of(
                  context,
                ).push(PhotoOverlayPage.route(activity)),
              ),
              const SizedBox(width: 10),
              CircleIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'ลบ',
                size: 44,
                iconColor: AppColors.negative,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      start: [
        stagger(_MapCard(activity: activity, insights: insights)),
        const SizedBox(height: 20),
        stagger(_TitleBlock(activity: activity, weather: state.weather)),
        const SizedBox(height: 16),
        stagger(_StatBento(activity: activity, insights: insights)),
      ],
      end: [
        stagger(
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).push(PhotoOverlayPage.route(activity)),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('ใส่เส้นทางและสถิติลงรูปภาพ'),
          ),
        ),
        const SizedBox(height: 16),
        stagger(_EnergyCard(activity)),
        if (activity.type != ActivityType.ride) ...[
          const SizedBox(height: 12),
          stagger(_ShoeRow(activity)),
        ],
        if (splits.isNotEmpty) ...[
          const SizedBox(height: 28),
          stagger(
            SectionHeader(
              'สปลิต (Splits)',
              action: Text(
                'ระยะฐาน 1.0 ${units.distanceUnit}',
                style: AppText.monoLabel,
              ),
            ),
          ),
          const SizedBox(height: 12),
          stagger(_SplitsCard(splits)),
        ],
        const SizedBox(height: 28),
        stagger(
          SectionHeader(
            'ภาพบันทึกหลังวิ่ง',
            action: Text(
              '${state.photos.length} ภาพถ่าย',
              style: AppText.monoLabel.copyWith(color: AppColors.lime),
            ),
          ),
        ),
        const SizedBox(height: 12),
        stagger(_PhotoStrip(state)),
      ],
    );
  }

  static String _typeTag(ActivityType t) => switch (t) {
    ActivityType.run => 'OUTDOOR RUN',
    ActivityType.ride => 'OUTDOOR RIDE',
    ActivityType.hike => 'HIKE',
  };

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<ActivityDetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.negative,
        ),
        title: const Text('ลบกิจกรรมนี้?'),
        content: const Text(
          'กิจกรรมและรูปที่แนบจะถูกลบจากทุกเครื่องที่ซิงก์ไว้',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete();
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.activity, required this.insights});

  final Activity activity;
  final ActivityInsights insights;

  @override
  Widget build(BuildContext context) {
    final accuracy = insights.averageAccuracyMeters;
    final net = insights.netElevationMeters.round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 300,
        child: Stack(
          children: [
            Positioned.fill(
              child: RouteMap(
                segments: activity.segments,
                fitPadding: const EdgeInsets.fromLTRB(36, 64, 36, 72),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x660C0D0B),
                        Color(0x000C0D0B),
                        Color(0x000C0D0B),
                        Color(0xCC0C0D0B),
                      ],
                      stops: [0, 0.25, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (accuracy != null)
              Positioned(
                left: 14,
                top: 14,
                child: StatusPill(
                  text: 'GPS ±${accuracy.round()} M',
                  mono: true,
                  color: AppColors.lime,
                ),
              ),
            Positioned(
              right: 14,
              top: 14,
              child: StatusPill(
                text: '${net >= 0 ? '+' : ''}${net}m NET',
                icon: Icons.landscape_outlined,
                mono: true,
              ),
            ),
            Positioned(
              left: 16,
              bottom: 14,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LUMINESCENT TRACK', style: AppText.monoLabelSm),
                  Text(
                    '${context.units.distance(activity.distanceMeters)} '
                    '${context.units.unit.english} · '
                    '${activity.segments.length} segment'
                    '${activity.segments.length == 1 ? '' : 's'}',
                    style: AppText.metricSm.copyWith(color: AppColors.lime),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.activity, required this.weather});

  final Activity activity;
  final WeatherReport? weather;

  @override
  Widget build(BuildContext context) {
    final night = activity.startedAt.hour >= 18 || activity.startedAt.hour < 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              night ? Icons.nightlight_round : Icons.wb_sunny_outlined,
              color: AppColors.lime,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(activity.title, style: AppText.headlineMd)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(formatDateTime(activity.startedAt), style: AppText.monoLabel),
            AnimatedOpacity(
              opacity: weather == null ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              child: weather == null
                  ? const SizedBox.shrink()
                  : Text(
                      '•  ${weather!.temperatureLabel} ${weather!.description}',
                      style: AppText.monoLabel.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBento extends StatelessWidget {
  const _StatBento({required this.activity, required this.insights});

  final Activity activity;
  final ActivityInsights insights;

  @override
  Widget build(BuildContext context) {
    final speed = activity.summary.averageSpeedMps;
    final vs = insights.distanceVsAveragePercent;
    final grade = activity.distanceMeters <= 0
        ? 0
        : activity.elevationGainMeters / activity.distanceMeters * 100;
    final paused = insights.totalTime - activity.movingTime;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BentoStat(
                  label: 'ระยะทาง',
                  value: context.units.distance(activity.distanceMeters),
                  numeric: context.units.distanceValue(activity.distanceMeters),
                  format: (v) => v.toStringAsFixed(2),
                  unit: context.units.distanceUnit,
                  valueStyle: AppText.metricMd,
                  footer: vs == null
                      ? 'ครั้งแรก'
                      : '${vs >= 0 ? '+' : ''}${vs.round()}% เฉลี่ย',
                  footerIcon: vs == null
                      ? null
                      : vs >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  footerColor: vs == null
                      ? null
                      : vs >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BentoStat(
                  label: activity.type.usesPace ? 'เพซเฉลี่ย' : 'ความเร็ว',
                  value: activity.type.usesPace
                      ? context.units.pace(speed)
                      : context.units.speed(speed),
                  unit: activity.type.usesPace
                      ? context.units.paceUnit
                      : context.units.speedUnit,
                  valueStyle: AppText.metricMd,
                  footer: switch (insights.effort) {
                    Effort.easy => 'สบายๆ',
                    Effort.steady => 'คงที่',
                    Effort.tempo => 'เร็วกว่าปกติ',
                    null => '—',
                  },
                  footerIcon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BentoStat(
                  label: 'ขึ้นสะสม',
                  value: '${activity.elevationGainMeters.round()}',
                  numeric: activity.elevationGainMeters,
                  format: (v) => '${v.round()}',
                  unit: 'ม.',
                  valueStyle: AppText.metricMd,
                  footer: grade < 1
                      ? 'ราบเรียบ'
                      : grade < 3
                      ? 'เนินเล็กน้อย'
                      : 'ทางชัน',
                  footerIcon: Icons.landscape_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BentoStat(
                label: 'เวลาเคลื่อนที่',
                icon: Icons.timer_outlined,
                value: formatDuration(activity.movingTime),
                footer:
                    '${(insights.activeRate * 100).toStringAsFixed(1)}% Active Rate',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BentoStat(
                label: 'เวลาทั้งหมด',
                icon: Icons.schedule_rounded,
                value: formatDuration(insights.totalTime),
                footer: paused.inSeconds < 5
                    ? 'ไม่มีการหยุดพัก'
                    : 'หยุดพัก ${formatDuration(paused)}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Calories in place of the reference design's heart-rate card: the app
/// has no HR sensor, but energy is estimated from distance and weight.
class _EnergyCard extends StatelessWidget {
  const _EnergyCard(this.activity);

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final weight = context.select((ProfileCubit c) => c.state.weightKg);
    final kcal = estimateCalories(
      type: activity.type,
      distanceMeters: activity.distanceMeters,
      movingTime: activity.movingTime,
      weightKg: weight,
    );
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_outlined,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('พลังงานที่ใช้', style: AppText.bodyLg),
                Text(
                  weight == null
                      ? 'ประมาณจากน้ำหนัก ${kDefaultWeightKg.round()} กก. · ตั้งน้ำหนักได้ในบัญชี'
                      : 'ประมาณจากน้ำหนัก ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} กก.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${kcal.round()}', style: AppText.metricLg),
                TextSpan(
                  text: ' KCAL',
                  style: AppText.monoLabel.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitsCard extends StatelessWidget {
  const _SplitsCard(this.splits);

  final List<ActivitySplit> splits;

  @override
  Widget build(BuildContext context) {
    final fastest = splits.map((s) => s.averageSpeedMps).reduce(math.max);
    final slowest = splits.map((s) => s.averageSpeedMps).reduce(math.min);
    final units = context.units;
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(units.distanceUnit, style: AppText.caption),
              ),
              const SizedBox(
                width: 72,
                child: Text('เพซ', style: AppText.caption),
              ),
              const Expanded(
                child: Text(
                  'เกณฑ์ความเร็วสัมพัทธ์',
                  textAlign: TextAlign.end,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, split) in splits.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      split.distanceMeters < units.unit.meters
                          ? units.distance(split.distanceMeters)
                          : '${split.index}',
                      style: AppText.metricSm,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      units.pace(split.averageSpeedMps),
                      style: AppText.metricSm.copyWith(
                        color: split.averageSpeedMps == fastest
                            ? AppColors.lime
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _SplitBar(
                      value: fastest <= 0 ? 0 : split.averageSpeedMps / fastest,
                      slowest:
                          split.averageSpeedMps == slowest && splits.length > 1,
                      delay: i,
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

class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.value,
    required this.slowest,
    required this.delay,
  });

  final double value;
  final bool slowest;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: Duration(milliseconds: 700 + 60 * delay.clamp(0, 10)),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: slowest
                    ? const [AppColors.negative, AppColors.negative]
                    : const [AppColors.mint, AppColors.lime],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip(this.state);

  final ActivityDetailState state;

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ActivityDetailCubit>();
    final source = context.read<PhotoSource>();
    final origin = await showModalBottomSheet<PhotoOrigin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, PhotoOrigin.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () => Navigator.pop(context, PhotoOrigin.gallery),
            ),
          ],
        ),
      ),
    );
    if (origin == null) return;
    final bytes = await source.pick(origin);
    if (bytes != null) await cubit.addPhoto(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final photo in state.photos) ...[
            _PhotoTile(photo),
            const SizedBox(width: 12),
          ],
          Pressable(
            onTap: state.addingPhoto ? null : () => _add(context),
            child: Container(
              width: state.photos.isEmpty ? 320 : 150,
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Center(
                child: state.addingPhoto
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.lime,
                            size: 30,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.photos.isEmpty
                                ? 'เพิ่มรูปบรรยากาศหลังวิ่ง'
                                : 'เพิ่มรูป',
                            style: AppText.label,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile(this.photo);

  final ActivityPhoto photo;

  @override
  Widget build(BuildContext context) {
    final path = photo.localPath;
    final time =
        '${photo.takenAt.hour.toString().padLeft(2, '0')}:'
        '${photo.takenAt.minute.toString().padLeft(2, '0')} น.';
    return Pressable(
      onTap: path == null ? null : () => _open(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path == null)
                const Shimmer(radius: 0)
              else
                Hero(
                  tag: 'photo-${photo.id}',
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    frameBuilder: (context, child, frame, sync) =>
                        AnimatedOpacity(
                          opacity: frame == null && !sync ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: child,
                        ),
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.surfaceHigh,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: AppColors.lime,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ถ่ายเวลา $time',
                      style: AppText.monoLabel.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String path) {
    final cubit = context.read<ActivityDetailCubit>();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    child: Hero(
                      tag: 'photo-${photo.id}',
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'ปิด',
                          size: 44,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        CircleIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'ลบรูป',
                          size: 44,
                          iconColor: AppColors.negative,
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await cubit.deletePhoto(photo);
                          },
                        ),
                      ],
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

/// The shoe this activity counts toward; tap to change it.
class _ShoeRow extends StatelessWidget {
  const _ShoeRow(this.activity);

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final shoes = context.select((GearCubit c) => c.state.shoes);
    // A deleted or unknown shoe counts as none.
    final current = shoes.where((s) => s.id == activity.shoeId).firstOrNull;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      onTap: () => _pick(context, current?.id),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.limeSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: AppColors.lime,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รองเท้าที่ใช้', style: AppText.label),
                Text(
                  current?.name ??
                      (shoes.isEmpty
                          ? 'เพิ่มรองเท้าได้ที่หน้าข้อมูลผู้ใช้'
                          : 'ไม่ได้ระบุ'),
                  style: AppText.bodyLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (shoes.isNotEmpty)
            const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, String? currentId) async {
    final shoes = context.read<GearCubit>().state.shoes;
    if (shoes.isEmpty) return;
    final cubit = context.read<ActivityDetailCubit>();
    // Sentinel for "no shoe": the sheet returns null when dismissed.
    const none = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text('เลือกรองเท้า', style: AppText.headlineSm),
          ),
          for (final shoe in shoes)
            if (!shoe.retired || shoe.id == currentId)
              ListTile(
                leading: Icon(
                  shoe.id == currentId
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: AppColors.lime,
                ),
                title: Text(shoe.name),
                subtitle: shoe.model == null ? null : Text(shoe.model!),
                onTap: () => Navigator.of(context).pop(shoe.id),
              ),
          ListTile(
            leading: Icon(
              currentId == null
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: AppColors.textSecondary,
            ),
            title: const Text('ไม่ระบุรองเท้า'),
            onTap: () => Navigator.of(context).pop(none),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await cubit.setShoe(picked == none ? null : picked);
    if (context.mounted) await context.refreshActivities();
  }
}
