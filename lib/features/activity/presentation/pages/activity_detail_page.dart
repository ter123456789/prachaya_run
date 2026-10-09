import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glass_stat_tile.dart';
import '../../../photo_share/presentation/pages/photo_overlay_page.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../activity_labels.dart';
import '../bloc/detail/activity_detail_cubit.dart';
import '../widgets/route_map.dart';
import '../widgets/speed_stat.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({super.key});

  static Route<void> route(String activityId) => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (context) =>
          ActivityDetailCubit(context.read<ActivityRepository>(), activityId)
            ..load(),
      child: const ActivityDetailPage(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActivityDetailCubit, ActivityDetailState>(
      listenWhen: (_, curr) => curr.status == ActivityDetailStatus.deleted,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) {
        final activity = state.activity;
        return Scaffold(
          body: switch (state.status) {
            ActivityDetailStatus.loaded => _Body(activity!),
            ActivityDetailStatus.notFound => const _Message('ไม่พบกิจกรรมนี้'),
            ActivityDetailStatus.failure => const _Message(
              'โหลดข้อมูลไม่สำเร็จ',
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Center(child: Text(text)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: 'กลับ',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.activity);

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final splits = activity.splits();
    final topInset = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 360 + topInset,
          child: Stack(
            children: [
              Positioned.fill(
                child: RouteMap(
                  segments: activity.segments,
                  fitPadding: EdgeInsets.fromLTRB(40, topInset + 72, 40, 56),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000C0D0B), AppColors.background],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topInset + 8,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'กลับ',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    CircleIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'ลบ',
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(activity.type.icon, color: AppColors.lime),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                formatDateTime(activity.startedAt),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _StatGrid(activity),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(PhotoOverlayPage.route(activity)),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('ใส่เส้นทางและสถิติลงรูปภาพ'),
              ),
              if (activity.type.usesPace && splits.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text(
                  'สปลิต',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                _SplitsCard(splits),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<ActivityDetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบกิจกรรมนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete();
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid(this.activity);

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 8, height: 8);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GlassStatTile(
                label: 'ระยะทาง',
                value: formatDistanceKm(activity.distanceMeters),
                unit: 'กม.',
                centered: true,
              ),
            ),
            gap,
            Expanded(
              child: SpeedStat(
                type: activity.type,
                speedMps: activity.summary.averageSpeedMps,
                centered: true,
              ),
            ),
            gap,
            Expanded(
              child: GlassStatTile(
                label: 'ขึ้นสะสม',
                value: '${activity.elevationGainMeters.round()}',
                unit: 'ม.',
                centered: true,
              ),
            ),
          ],
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: GlassStatTile(
                label: 'เวลาเคลื่อนที่',
                value: formatDuration(activity.movingTime),
                centered: true,
              ),
            ),
            gap,
            Expanded(
              child: GlassStatTile(
                label: 'เวลาทั้งหมด',
                value: formatDuration(
                  activity.endedAt.difference(activity.startedAt),
                ),
                centered: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitsCard extends StatelessWidget {
  const _SplitsCard(this.splits);

  final List<ActivitySplit> splits;

  @override
  Widget build(BuildContext context) {
    final fastest = splits.map((s) => s.averageSpeedMps).reduce(math.max);
    return GlassCard(
      child: Column(
        children: [
          const Row(
            children: [
              SizedBox(width: 44, child: Text('กม.', style: _headerStyle)),
              SizedBox(width: 64, child: Text('เพซ', style: _headerStyle)),
            ],
          ),
          const SizedBox(height: 8),
          for (final split in splits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      split.distanceMeters < 1000
                          ? (split.distanceMeters / 1000).toStringAsFixed(2)
                          : '${split.index}',
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(formatPace(split.averageSpeedMps)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fastest <= 0
                            ? 0
                            : split.averageSpeedMps / fastest,
                        minHeight: 8,
                        backgroundColor: AppColors.glassFill,
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

  static const _headerStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );
}
