import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/services/heart_rate_monitor.dart';
import '../bloc/heart_rate/heart_rate_cubit.dart';

/// Pair a chest strap, or a watch that broadcasts its heart rate. Scans
/// while open.
class HeartRateSensorSheet extends StatefulWidget {
  const HeartRateSensorSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<HeartRateCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const HeartRateSensorSheet()),
    );
  }

  @override
  State<HeartRateSensorSheet> createState() => _HeartRateSensorSheetState();
}

class _HeartRateSensorSheetState extends State<HeartRateSensorSheet> {
  late final HeartRateCubit _cubit = context.read<HeartRateCubit>();

  @override
  void initState() {
    super.initState();
    if (_cubit.state.sensor == null) _cubit.scan();
  }

  @override
  void dispose() {
    _cubit.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HeartRateCubit>().state;
    final sensor = state.sensor;
    final heartRate = state.found.where((d) => d.advertisesHeartRate);
    final others = state.found.where((d) => !d.advertisesHeartRate);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('เซนเซอร์ชีพจร', style: AppText.headlineMd),
            ),
            CircleIconButton(
              icon: Icons.close_rounded,
              tooltip: 'ปิด',
              size: 44,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Text(
          'สายคาดอก หรือนาฬิกาที่เปิดโหมดส่งค่าชีพจรผ่านบลูทูธ',
          style: AppText.caption,
        ),
        const SizedBox(height: 16),
        if (sensor != null)
          _Current(state)
        else ...[
          if (state.access case final access?
              when access != SensorAccess.granted)
            _AccessProblem(access, onRetry: _cubit.scan),
          _ScanHeader(scanning: state.scanning, onScan: _cubit.scan),
          for (final device in heartRate) _DeviceTile(device),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('อุปกรณ์อื่น', style: AppText.label),
            const Text(
              'นาฬิกาบางรุ่นแสดงค่าชีพจรหลังเชื่อมต่อแล้วเท่านั้น',
              style: AppText.caption,
            ),
            const SizedBox(height: 6),
            for (final device in others) _DeviceTile(device),
          ],
          if (state.access == SensorAccess.granted &&
              !state.scanning &&
              state.found.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('ไม่พบอุปกรณ์', style: AppText.body),
            ),
        ],
        const SizedBox(height: 20),
        const _Tips(),
      ],
    );
  }
}

class _Current extends StatelessWidget {
  const _Current(this.state);

  final HeartRateState state;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (state.link) {
      SensorLink.connected => ('เชื่อมต่อแล้ว', AppColors.mint),
      SensorLink.connecting => ('กำลังเชื่อมต่อ…', AppColors.textSecondary),
      SensorLink.noHeartRate => (
        'ไม่พบค่าชีพจร — เปิดโหมดส่งค่าชีพจรบนนาฬิกา',
        AppColors.negative,
      ),
      SensorLink.disconnected => ('ไม่ได้เชื่อมต่อ', AppColors.negative),
    };
    final bpm = state.bpm;
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: AppColors.lime),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.sensor!.name,
                  style: AppText.bodyLg,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                bpm == null ? '--' : '$bpm',
                style: AppText.metricMd.copyWith(color: AppColors.lime),
              ),
              const SizedBox(width: 4),
              const Text('bpm', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              text: state.skinContact == false ? 'เซนเซอร์ไม่แนบผิว' : text,
              dotColor: state.skinContact == false ? AppColors.negative : color,
              pulse: state.connected,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.read<HeartRateCubit>().disconnect().then((_) {
                if (context.mounted) context.read<HeartRateCubit>().scan();
              });
            },
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('เลิกใช้เซนเซอร์นี้'),
          ),
        ],
      ),
    );
  }
}

class _ScanHeader extends StatelessWidget {
  const _ScanHeader({required this.scanning, required this.onScan});

  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('อุปกรณ์ใกล้เคียง', style: AppText.label)),
        if (scanning)
          // The spinner loops, so it gives way to text under "remove
          // animations".
          MediaQuery.disableAnimationsOf(context)
              ? const Text('กำลังค้นหา…', style: AppText.caption)
              : const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
        else
          TextButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ค้นหาอีกครั้ง'),
          ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile(this.device);

  final HeartRateSensor device;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        device.advertisesHeartRate
            ? Icons.monitor_heart_outlined
            : Icons.watch_outlined,
        color: device.advertisesHeartRate
            ? AppColors.lime
            : AppColors.textSecondary,
      ),
      title: Text(device.name, style: AppText.body),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<HeartRateCubit>().connect(device);
      },
    );
  }
}

class _AccessProblem extends StatelessWidget {
  const _AccessProblem(this.access, {required this.onRetry});

  final SensorAccess access;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = switch (access) {
      SensorAccess.bluetoothOff => 'เปิดบลูทูธก่อน แล้วค้นหาอีกครั้ง',
      SensorAccess.denied =>
        'ต้องอนุญาตให้แอปใช้บลูทูธ (ตั้งค่าของเครื่อง → Prachaya Run)',
      SensorAccess.unsupported => 'เครื่องนี้ไม่รองรับบลูทูธ LE',
      SensorAccess.granted => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.negative),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body)),
          if (access == SensorAccess.bluetoothOff)
            TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ใช้นาฬิกาเป็นเซนเซอร์', style: AppText.label),
        SizedBox(height: 6),
        Text(
          '• Garmin: Broadcast Heart Rate\n'
          '• Huawei: HR Data Broadcasts\n'
          '• Amazfit: Heart Rate Push\n'
          '• Xiaomi Band: Heart rate broadcast\n'
          'เซนเซอร์ต่อได้ทีละแอป ถ้าไม่เจอ ให้ปิดการเชื่อมต่อกับแอปของนาฬิกาก่อน '
          'Apple Watch และ Fitbit ส่งค่าชีพจรแบบนี้ไม่ได้',
          style: AppText.caption,
        ),
      ],
    );
  }
}
