import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/services/heart_rate_zones.dart';
import '../athlete_labels.dart';

/// Five zones, top first, each bar as wide as the zone's upper % of Max HR.
/// The focus zone is lifted out with its purpose.
class HeartRateZonesCard extends StatelessWidget {
  const HeartRateZonesCard({
    super.key,
    required this.maxHr,
    required this.onSetUp,
  });

  /// Null until a birth year or Max HR is entered.
  final MaxHeartRate? maxHr;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final max = maxHr;
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'โซนอัตราการเต้นหัวใจ',
            icon: Icons.monitor_heart_outlined,
            action: max == null
                ? null
                : StatusPill(
                    text: 'เป้าหมาย: เน้น Zone $kFocusZone',
                    color: AppColors.secondary,
                    background: AppColors.secondary.withValues(alpha: 0.15),
                  ),
          ),
          const SizedBox(height: 14),
          if (max == null)
            _SetUp(onSetUp: onSetUp)
          else
            for (final zone in heartRateZones(max.bpm).reversed)
              _ZoneRow(zone, focus: zone.number == kFocusZone),
        ],
      ),
    );
  }
}

class _SetUp extends StatelessWidget {
  const _SetUp({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'กรอกปีเกิด (หรือ Max HR ของคุณ) เพื่อคำนวณโซน '
          'ด้วยสูตร Tanaka: 208 − 0.7 × อายุ',
          style: AppText.body,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSetUp,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('กรอกข้อมูลร่างกาย'),
        ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow(this.zone, {required this.focus});

  final HeartRateZone zone;
  final bool focus;

  Color get _color => switch (zone.number) {
    5 => AppColors.textMuted,
    4 => AppColors.lime.withValues(alpha: 0.55),
    3 => AppColors.secondary.withValues(alpha: 0.75),
    2 => AppColors.mint,
    _ => AppColors.textMuted.withValues(alpha: 0.35),
  };

  String get _range => zone.number == 5
      ? '≥${zone.lowBpm} bpm'
      : '${zone.lowBpm} - ${zone.highBpm} bpm';

  @override
  Widget build(BuildContext context) {
    final label = 'Zone ${zone.number} • ${zoneName(zone.number)}';
    final bar = _Bar(fraction: zone.highPercent / 100, color: _color);
    if (!focus) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppText.monoLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _range,
                  style: AppText.monoLabel.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            bar,
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  color: AppColors.mint,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$label $_range',
                  style: AppText.monoLabel.copyWith(color: AppColors.mint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          bar,
          const SizedBox(height: 8),
          const Text(kFocusZoneHint, style: AppText.label),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 8,
          color: color,
          backgroundColor: AppColors.surfaceHighest,
        ),
      ),
    );
  }
}
