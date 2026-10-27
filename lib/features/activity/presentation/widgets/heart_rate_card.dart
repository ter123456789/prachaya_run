import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../athlete/domain/services/heart_rate_zones.dart';
import '../../../athlete/presentation/athlete_labels.dart';
import '../../../athlete/presentation/widgets/heart_rate_zones_card.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../domain/entities/heart_rate.dart';
import '../../domain/services/heart_rate_summary.dart';

/// Average / max heart rate, the curve over time and time in each zone
/// (zones need a Max HR: entered, or Tanaka from the birth year).
class HeartRateCard extends StatelessWidget {
  const HeartRateCard(this.heartRate, {super.key});

  final HeartRateTrack heartRate;

  @override
  Widget build(BuildContext context) {
    final profile = context.select((ProfileCubit c) => c.state.profile);
    final maxHr = resolveMaxHr(
      enteredBpm: profile.maxHrBpm,
      birthYear: profile.birthYear,
      today: DateTime.now(),
    );
    final zones = maxHr == null ? null : heartRateZones(maxHr.bpm);
    final summary = summarizeHeartRate(
      heartRate.samples,
      zoneLowBpm: zones?.map((z) => z.lowBpm).toList(),
    );
    if (summary == null) return const SizedBox.shrink();
    final total = summary.zoneTimes.fold(Duration.zero, (a, b) => a + b);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'อัตราการเต้นหัวใจ',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Figure('เฉลี่ย', summary.averageBpm)),
              Expanded(
                child: _Figure('สูงสุด', summary.maxBpm, color: AppColors.lime),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _HeartRateCurvePainter(heartRate.samples),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 16),
          if (zones == null)
            const Text(
              'กรอกปีเกิดหรือ Max HR ในโปรไฟล์ เพื่อดูเวลาในแต่ละโซน',
              style: AppText.caption,
            )
          else if (summary.sparse)
            const Text(
              'ค่าชีพจรห่างเกินไปสำหรับคำนวณเวลาในโซน',
              style: AppText.caption,
            )
          else
            for (final zone in zones.reversed)
              _ZoneTime(
                zone: zone,
                time: summary.zoneTimes[zone.number - 1],
                total: total,
              ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.bpm, {this.color});

  final String label;
  final int bpm;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$bpm',
                style: AppText.metricLg.copyWith(color: color),
              ),
              TextSpan(
                text: ' BPM',
                style: AppText.monoLabel.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneTime extends StatelessWidget {
  const _ZoneTime({
    required this.zone,
    required this.time,
    required this.total,
  });

  final HeartRateZone zone;
  final Duration time;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == Duration.zero
        ? 0.0
        : time.inMilliseconds / total.inMilliseconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text('Z${zone.number}', style: AppText.monoLabel),
          ),
          Expanded(
            child: Tooltip(
              message: zoneName(zone.number),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    color: heartRateZoneColor(zone.number),
                    backgroundColor: AppColors.surfaceHighest,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              formatDuration(time),
              textAlign: TextAlign.end,
              style: AppText.monoLabel.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// bpm over time; a gap of more than 30 s (sensor dropped out, or a
/// pause) breaks the line.
class _HeartRateCurvePainter extends CustomPainter {
  _HeartRateCurvePainter(this.samples);

  final List<HeartRateSample> samples;

  static const _gap = Duration(seconds: 30);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final start = samples.first.timestamp;
    final span = samples.last.timestamp.difference(start).inMilliseconds;
    if (span <= 0) return;
    var low = samples.first.bpm;
    var high = low;
    for (final s in samples) {
      low = math.min(low, s.bpm);
      high = math.max(high, s.bpm);
    }
    final range = math.max(high - low, 10);
    Offset at(HeartRateSample s) => Offset(
      size.width * s.timestamp.difference(start).inMilliseconds / span,
      size.height * (1 - (s.bpm - low) / range) * 0.9 + size.height * 0.05,
    );
    final line = Path();
    for (var i = 0; i < samples.length; i++) {
      final p = at(samples[i]);
      final breaks =
          i == 0 ||
          samples[i].timestamp.difference(samples[i - 1].timestamp) > _gap;
      breaks ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.mint, AppColors.lime],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_HeartRateCurvePainter old) =>
      !identical(old.samples, samples);
}
