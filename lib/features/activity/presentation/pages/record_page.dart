import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/content_width.dart';
import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/activity_type.dart';
import '../../domain/entities/route_shape.dart';
import '../../domain/services/live_metrics.dart';
import '../../../../core/units/unit_labels.dart';
import '../../../athlete/presentation/units.dart';
import '../activity_labels.dart';
import '../activity_refresh.dart';
import '../bloc/record/record_bloc.dart';
import '../widgets/route_canvas.dart';
import '../widgets/route_map.dart';
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
        return Scaffold(
          body: GlowBackground(
            glowHeight: 220,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Landscape (foldable inner screen, or any phone turned
                  // sideways): the track beside the numbers.
                  final side =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxWidth >= 600;
                  return MaxWidth(
                    maxWidth: side
                        ? Breakpoints.wideContent
                        : Breakpoints.content,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          AppTopBar(
                            title: 'บันทึกกิจกรรม',
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(height: 8),
                          _StatusRow(state),
                          const SizedBox(height: 12),
                          if (side)
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _TrackPanel(state)),
                                  const SizedBox(width: Breakpoints.paneGap),
                                  SizedBox(width: 380, child: _Readouts(state)),
                                ],
                              ),
                            )
                          else ...[
                            Expanded(child: _TrackPanel(state)),
                            const SizedBox(height: 12),
                            _Timer(state),
                            const SizedBox(height: 12),
                            _Tiles(state),
                            const SizedBox(height: 20),
                            _Controls(state),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onStateChanged(BuildContext context, RecordState state) async {
    final failure = state.failure;
    if (failure != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.negative,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_failureMessage(failure))),
              ],
            ),
          ),
        );
    }
    final savedId = state.savedActivityId;
    if (state.status == RecordStatus.saved && savedId != null) {
      HapticFeedback.mediumImpact();
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

/// Timer, tiles and controls as one column beside the track (landscape);
/// scrolls if the screen is too short for all of it.
class _Readouts extends StatelessWidget {
  const _Readouts(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Timer(state),
              const SizedBox(height: 12),
              _Tiles(state),
              const SizedBox(height: 20),
              _Controls(state),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (state.status) {
      RecordStatus.idle => ('พร้อมเริ่ม${state.type.label}', AppColors.mint),
      RecordStatus.recording => (
        'กำลังบันทึก${state.type.label}',
        AppColors.lime,
      ),
      RecordStatus.paused => ('หยุดชั่วคราว', AppColors.negative),
      RecordStatus.saving ||
      RecordStatus.saved => ('กำลังบันทึกข้อมูล…', AppColors.mint),
    };
    double? accuracy;
    for (final s in state.segments.reversed) {
      if (s.isNotEmpty) {
        accuracy = s.last.accuracyMeters;
        break;
      }
    }
    final (gps, gpsColor) = !state.isActive
        ? ('GPS พร้อม', AppColors.textSecondary)
        : accuracy == null
        ? ('รอสัญญาณ GPS', AppColors.textSecondary)
        : accuracy <= 10
        ? ('GPS แม่นยำ', AppColors.secondary)
        : accuracy <= 20
        ? ('GPS ปานกลาง', AppColors.lime)
        : ('GPS อ่อน', AppColors.negative);
    return Row(
      children: [
        // Shrinks instead of overflowing on narrow screens.
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: StatusPill(
                  key: ValueKey(text),
                  text: text,
                  dotColor: color,
                  pulse: state.status == RecordStatus.recording,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(
          text: gps,
          icon: Icons.satellite_alt_rounded,
          color: gpsColor,
        ),
      ],
    );
  }
}

class _TrackPanel extends StatefulWidget {
  const _TrackPanel(this.state);

  final RecordState state;

  @override
  State<_TrackPanel> createState() => _TrackPanelState();
}

class _TrackPanelState extends State<_TrackPanel> {
  bool _map = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasTrack = state.segments.any((s) => s.length > 1);
    final live = recentSpeedMps(state.segments);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: !hasTrack
                    ? _Waiting(state: state)
                    : _map
                    ? RouteMap(
                        key: const ValueKey('map'),
                        segments: state.segments,
                        followLatest: true,
                      )
                    : RouteCanvas(
                        key: const ValueKey('canvas'),
                        shape: RouteShape.fromSegments(state.segments),
                        live: state.status == RecordStatus.recording,
                        padding: 0.16,
                      ),
              ),
            ),
            if (hasTrack) ...[
              Positioned(
                left: 12,
                top: 12,
                child: CircleIconButton(
                  icon: _map ? Icons.grain_rounded : Icons.layers_outlined,
                  tooltip: _map ? 'มุมมองเส้นทาง' : 'มุมมองแผนที่',
                  size: 40,
                  onPressed: () => setState(() => _map = !_map),
                ),
              ),
              if (live != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: StatusPill(
                    text: state.type.usesPace
                        ? '${context.units.paceQuote(live)} LIVE PACE'
                        : '${context.units.speed(live)} '
                              '${context.units.unit.latinSpeed} LIVE',
                    dotColor: AppColors.lime,
                    mono: true,
                    color: AppColors.lime,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.state});

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final idle = state.status == RecordStatus.idle;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (idle)
            PillTabs<ActivityType>(
              items: ActivityType.values,
              selected: state.type,
              labelOf: (t) => t.label,
              iconOf: (t) => t.icon,
              onChanged: (t) =>
                  context.read<RecordBloc>().add(RecordTypeChanged(t)),
            ),
          Expanded(
            child: Center(
              // Shrinks rather than overflows on short screens (foldable
              // outer screen, landscape).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.limeSoft,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(
                        idle ? state.type.icon : Icons.gps_not_fixed_rounded,
                        size: 40,
                        color: AppColors.lime,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      idle ? 'เลือกประเภทแล้วกดเริ่ม' : 'กำลังรอสัญญาณ GPS…',
                      style: AppText.body,
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

class _Timer extends StatelessWidget {
  const _Timer(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final recording = state.status == RecordStatus.recording;
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          const Text('เวลา', style: AppText.label),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              FittedBox(
                child: Text(
                  formatDuration(state.movingTime),
                  style: AppText.metricHero.copyWith(fontSize: 56, height: 1.1),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedOpacity(
                opacity: state.isActive ? 1 : 0.3,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  recording ? 'REC' : 'PAUSE',
                  style: AppText.monoLabel.copyWith(
                    color: recording ? AppColors.lime : AppColors.negative,
                  ),
                ),
              ),
            ],
          ),
          if (state.isActive) _LapLine(state),
        ],
      ),
    );
  }
}

/// The lap under way and the button that ends it.
class _LapLine extends StatelessWidget {
  const _LapLine(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final units = context.units;
    final recording = state.status == RecordStatus.recording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          const PulseDot(color: AppColors.mint, size: 7),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'รอบที่ ${state.lapNumber} • '
              '${units.distance(state.lapDistanceMeters)} ${units.distanceUnit} • '
              '${formatDuration(state.lapTime)}',
              style: AppText.monoLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: recording
                ? () {
                    HapticFeedback.selectionClick();
                    context.read<RecordBloc>().add(const RecordLapped());
                  }
                : null,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('เพิ่ม Lap'),
          ),
        ],
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles(this.state);

  final RecordState state;

  @override
  Widget build(BuildContext context) {
    final speed = state.averageSpeedMps;
    return Row(
      children: [
        _Tile(
          label: state.type.usesPace ? 'เพซเฉลี่ย' : 'ความเร็ว',
          value: state.type.usesPace
              ? context.units.pace(speed)
              : context.units.speed(speed),
          unit: state.type.usesPace
              ? context.units.paceUnit
              : context.units.speedUnit,
        ),
        const SizedBox(width: 10),
        _Tile(
          label: 'ระยะทาง',
          value: context.units.distance(state.distanceMeters),
          unit: context.units.distanceUnit,
          color: AppColors.lime,
        ),
        const SizedBox(width: 10),
        _Tile(
          label: 'ขึ้นสะสม',
          value: '${state.elevationGainMeters.round()}',
          unit: 'ม.',
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
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
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.label),
            const SizedBox(height: 4),
            FittedBox(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, a) =>
                    FadeTransition(opacity: a, child: child),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: AppText.metricLg.copyWith(color: color),
                ),
              ),
            ),
            Text(unit, style: AppText.caption),
          ],
        ),
      ),
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
            dimension: 88,
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
            onPressed: () {
              HapticFeedback.mediumImpact();
              bloc.add(switch (status) {
                RecordStatus.recording => const RecordPaused(),
                RecordStatus.paused => const RecordResumed(),
                _ => const RecordStarted(),
              });
            },
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Side(
          visible: state.isActive,
          child: CircleIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'ทิ้ง',
            size: 56,
            iconColor: AppColors.negative,
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
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.negative,
        ),
        title: const Text('ทิ้งกิจกรรมนี้?'),
        content: const Text(
          'ข้อมูลที่บันทึกไว้จะหายไปทั้งหมด',
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
    return AnimatedScale(
      scale: visible ? 1 : 0.6,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}
