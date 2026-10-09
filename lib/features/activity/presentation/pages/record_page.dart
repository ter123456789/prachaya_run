import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_stat_tile.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../domain/entities/activity_type.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/record/record_bloc.dart';
import '../widgets/route_map.dart';
import '../widgets/speed_stat.dart';
import 'activity_detail_page.dart';

/// Full-screen recorder. Leaving it does not stop a recording; the bloc
/// lives above the navigator and the home orb leads back here.
class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const RecordPage());

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordBloc, RecordState>(
      listenWhen: (prev, curr) =>
          (curr.failure != null && prev.failure != curr.failure) ||
          (curr.status == RecordStatus.saved &&
              prev.status != RecordStatus.saved),
      listener: _onStateChanged,
      builder: (context, state) {
        final hasTrack = state.segments.any((s) => s.isNotEmpty);
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: hasTrack
                    ? RouteMap(segments: state.segments, followLatest: true)
                    : GlowBackground(child: _Waiting(status: state.status)),
              ),
              // Darken the bottom so tiles stay legible over the map.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 360,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000C0D0B), Color(0xE60C0D0B)],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _TopBar(state),
                      if (state.status == RecordStatus.idle) ...[
                        const SizedBox(height: 16),
                        PillTabs<ActivityType>(
                          items: ActivityType.values,
                          selected: state.type,
                          labelOf: (t) => t.label,
                          iconOf: (t) => t.icon,
                          onChanged: (t) => context.read<RecordBloc>().add(
                            RecordTypeChanged(t),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _StatsGrid(state),
                      const SizedBox(height: 24),
                      _Controls(state),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onStateChanged(BuildContext context, RecordState state) async {
    final failure = state.failure;
    if (failure != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_failureMessage(failure))));
    }
    final savedId = state.savedActivityId;
    if (state.status == RecordStatus.saved && savedId != null) {
      context.read<RecordBloc>().add(const RecordReset());
      final navigator = Navigator.of(context);
      await context.refreshActivities();
      navigator.pushReplacement(ActivityDetailPage.route(savedId));
    }
  }

  static String _failureMessage(RecordFailure failure) => switch (failure) {
    RecordFailure.permissionDenied => 'ต้องอนุญาตการเข้าถึงตำแหน่งเพื่อบันทึก',
    RecordFailure.permissionDeniedForever =>
      'การเข้าถึงตำแหน่งถูกปิด กรุณาเปิดในการตั้งค่าของเครื่อง',
    RecordFailure.serviceDisabled => 'กรุณาเปิด GPS / Location Services',
    RecordFailure.locationLost => 'สัญญาณ GPS ขาดหาย หยุดบันทึกชั่วคราวแล้ว',
    RecordFailure.tooShort => 'ระยะทางสั้นเกินไป ไปต่ออีกหน่อยหรือกดทิ้ง',
    RecordFailure.saveFailed => 'บันทึกไม่สำเร็จ ลองอีกครั้ง',
  };
}

class _TopBar extends StatelessWidget {
  const _TopBar(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final title = switch (state.status) {
      RecordStatus.idle => 'บันทึกกิจกรรม',
      RecordStatus.recording => 'กำลังบันทึก${state.type.label}',
      RecordStatus.paused => 'หยุดชั่วคราว',
      RecordStatus.saving || RecordStatus.saved => 'กำลังบันทึกข้อมูล…',
    };
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back,
          tooltip: 'กลับ',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.status});

  final RecordStatus status;

  @override
  Widget build(BuildContext context) {
    final waiting = status == RecordStatus.recording;
    return Align(
      alignment: const Alignment(0, -0.2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            waiting ? Icons.gps_not_fixed : Icons.route,
            size: 56,
            color: AppColors.lime,
          ),
          const SizedBox(height: 12),
          Text(
            waiting ? 'กำลังรอสัญญาณ GPS…' : 'เลือกประเภทแล้วกดเริ่ม',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SpeedStat(
                type: state.type,
                speedMps: state.averageSpeedMps,
                blur: true,
                centered: true,
              ),
            ),
            gap,
            Expanded(
              child: GlassStatTile(
                label: 'ระยะทาง',
                value: formatDistanceKm(state.distanceMeters),
                unit: 'กม.',
                blur: true,
                centered: true,
              ),
            ),
            gap,
            Expanded(
              child: GlassStatTile(
                label: 'ขึ้นสะสม',
                value: '${state.elevationGainMeters.round()}',
                unit: 'ม.',
                blur: true,
                centered: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassStatTile(
          label: 'เวลา',
          value: formatDuration(state.movingTime),
          valueSize: 40,
          blur: true,
          centered: true,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RecordBloc>();
    final status = state.status;
    final busy = status == RecordStatus.saving || status == RecordStatus.saved;

    final Widget primary = busy
        ? const SizedBox.square(
            dimension: 104,
            child: Center(child: CircularProgressIndicator()),
          )
        : CircleIconButton(
            size: 88,
            filled: true,
            tooltip: switch (status) {
              RecordStatus.recording => 'หยุดชั่วคราว',
              RecordStatus.paused => 'ทำต่อ',
              _ => 'เริ่ม',
            },
            icon: status == RecordStatus.recording
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onPressed: () => bloc.add(switch (status) {
              RecordStatus.recording => const RecordPaused(),
              RecordStatus.paused => const RecordResumed(),
              _ => const RecordStarted(),
            }),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Side(
          visible: state.isActive,
          child: CircleIconButton(
            icon: Icons.delete_outline,
            tooltip: 'ทิ้ง',
            size: 56,
            onPressed: () => _confirmDiscard(context),
          ),
        ),
        primary,
        _Side(
          visible: state.isActive,
          child: CircleIconButton(
            icon: Icons.stop_rounded,
            tooltip: 'จบและบันทึก',
            size: 56,
            onPressed: () => bloc.add(const RecordFinished()),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final bloc = context.read<RecordBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ทิ้งกิจกรรมนี้?'),
        content: const Text('ข้อมูลที่บันทึกไว้จะหายไปทั้งหมด'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ทิ้ง'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) bloc.add(const RecordReset());
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(ignoring: !visible, child: child),
    );
  }
}
