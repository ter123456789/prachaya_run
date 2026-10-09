import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../../core/widgets/glass_stat_tile.dart';
import '../../domain/entities/activity_type.dart';
import '../activity_labels.dart';

/// Pace for runs/hikes, speed for rides.
class SpeedStat extends StatelessWidget {
  const SpeedStat({
    super.key,
    required this.type,
    required this.speedMps,
    this.blur = false,
    this.centered = false,
    this.showIcon = false,
  });

  final ActivityType type;
  final double speedMps;
  final bool blur;
  final bool centered;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return type.usesPace
        ? GlassStatTile(
            label: 'เพซเฉลี่ย',
            value: formatPace(speedMps),
            unit: '/กม.',
            icon: showIcon ? Icons.speed : null,
            blur: blur,
            centered: centered,
          )
        : GlassStatTile(
            label: 'ความเร็วเฉลี่ย',
            value: formatSpeedKmh(speedMps),
            unit: 'กม./ชม.',
            icon: showIcon ? Icons.speed : null,
            blur: blur,
            centered: centered,
          );
  }
}
