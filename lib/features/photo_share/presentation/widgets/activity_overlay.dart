import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../../activity/domain/entities/activity.dart';
import '../../../activity/domain/entities/route_shape.dart';
import '../../../activity/presentation/activity_labels.dart';
import '../../../activity/presentation/widgets/route_painter.dart';
import '../bloc/photo_overlay_cubit.dart';

typedef _StatItem = ({IconData icon, String label, String value});

/// The route + stats graphic laid over a photo. Everything scales with the
/// frame width so the preview and the 1080 px export look identical.
class ActivityOverlay extends StatelessWidget {
  const ActivityOverlay({
    super.key,
    required this.activity,
    required this.route,
    required this.layout,
    required this.color,
    this.stats = PhotoOverlayState.defaultStats,
    this.language = OverlayLanguage.th,
    this.routeColor,
    this.showHeader = false,
    this.cutout = false,
  });

  final Activity activity;
  final RouteShape route;
  final OverlayLayout layout;
  final Color color;
  final List<OverlayStat> stats;
  final OverlayLanguage language;

  /// Defaults to [color].
  final Color? routeColor;

  /// Title and date at the top; used on the plain card background where
  /// there is no photo to give context.
  final bool showHeader;

  /// Transparent export: only text and route, with no shadows or tile
  /// backgrounds left behind as grey halos.
  final bool cutout;

  /// Light ink gets a shadow so it stays readable on bright photos.
  bool get _needsShadow => !cutout && color.computeLuminance() > 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final u = constraints.maxWidth / 360;
        final stats = [
          for (final s in this.stats) _item(activity, s, language),
        ];
        final brand = FittedBox(
          fit: BoxFit.scaleDown,
          child: _Brand(activity, u: u, color: color),
        );
        Widget routeBox() => CustomPaint(
          size: Size.infinite,
          painter: RoutePainter(
            shape: route,
            color: routeColor ?? color,
            strokeWidth: 4 * u,
            shadow: _needsShadow,
          ),
        );

        final content = switch (layout) {
          OverlayLayout.classic => Column(
            children: [
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        for (final s in stats) ...[
                          _Stat(s, u: u, valueSize: 38, color: color),
                          SizedBox(height: 14 * u),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(80 * u, 4 * u, 80 * u, 16 * u),
                  child: routeBox(),
                ),
              ),
              Text(
                'PRACHAYA RUN',
                style: TextStyle(
                  fontSize: 20 * u,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5 * u,
                ),
              ),
            ],
          ),
          OverlayLayout.glass => Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(36 * u, 28 * u, 36 * u, 16 * u),
                  child: routeBox(),
                ),
              ),
              Row(
                children: [
                  for (final s in stats)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3 * u),
                        child: _GlassStat(s, u: u, color: color, plain: cutout),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 14 * u),
              brand,
            ],
          ),
          OverlayLayout.full => Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(24 * u),
                  child: routeBox(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final s in stats)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Stat(s, u: u, valueSize: 26, color: color),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16 * u),
              brand,
            ],
          ),
          OverlayLayout.statsOnly => Align(
            alignment: Alignment.bottomLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in stats) ...[
                    _Stat(
                      s,
                      u: u,
                      valueSize: 38,
                      color: color,
                      alignStart: true,
                    ),
                    SizedBox(height: 10 * u),
                  ],
                  brand,
                ],
              ),
            ),
          ),
          OverlayLayout.routeOnly => Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(32 * u),
                  child: routeBox(),
                ),
              ),
              brand,
            ],
          ),
        };

        return DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'Prompt',
            color: color,
            shadows: _needsShadow && layout != OverlayLayout.glass
                ? const [Shadow(blurRadius: 8, color: Colors.black54)]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(20 * u),
            child: showHeader
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(activity, u: u),
                      SizedBox(height: 12 * u),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
        );
      },
    );
  }

  static _StatItem _item(Activity a, OverlayStat stat, OverlayLanguage lang) {
    final en = lang == OverlayLanguage.en;
    final speed = a.summary.averageSpeedMps;
    final km = en ? 'km' : 'กม.';
    return switch (stat) {
      OverlayStat.distance => (
        icon: Icons.route,
        label: en ? 'Distance' : 'ระยะทาง',
        value: '${formatDistanceKm(a.distanceMeters)} $km',
      ),
      OverlayStat.avgSpeed => (
        icon: Icons.speed,
        label: en ? 'Avg Speed' : 'ความเร็วเฉลี่ย',
        value: '${formatSpeedKmh(speed)} ${en ? 'km/h' : 'กม./ชม.'}',
      ),
      OverlayStat.pace => (
        icon: Icons.av_timer,
        label: en ? 'Pace' : 'เพซ',
        value: '${formatPace(speed)} /$km',
      ),
      OverlayStat.time => (
        icon: Icons.timer_outlined,
        label: en ? 'Time' : 'เวลา',
        value: en
            ? formatDurationShort(a.movingTime)
            : formatDuration(a.movingTime),
      ),
      OverlayStat.elevation => (
        icon: Icons.terrain_outlined,
        label: en ? 'Elev Gain' : 'ขึ้นสะสม',
        value: '${a.elevationGainMeters.round()} ${en ? 'm' : 'ม.'}',
      ),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header(this.activity, {required this.u});

  final Activity activity;
  final double u;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 22 * u, fontWeight: FontWeight.w500),
        ),
        Text(
          formatDateTime(activity.startedAt),
          style: TextStyle(fontSize: 11 * u),
        ),
      ],
    );
  }
}

/// Frosted tile like the floating stat chips in the reference design.
class _GlassStat extends StatelessWidget {
  const _GlassStat(
    this.item, {
    required this.u,
    required this.color,
    this.plain = false,
  });

  final _StatItem item;
  final double u;
  final Color color;

  /// Content only, without the frosted tile.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: 10 * u, vertical: 10 * u);
    if (plain) return Padding(padding: padding, child: _content());
    final radius = BorderRadius.circular(14 * u);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10 * u, sigmaY: 10 * u),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.black.withValues(alpha: 0.28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: u,
            ),
          ),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, size: 16 * u, color: color),
        SizedBox(height: 4 * u),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10 * u,
            color: color.withValues(alpha: 0.8),
          ),
        ),
        Text(
          item.value,
          style: TextStyle(
            fontSize: 17 * u,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(
    this.item, {
    required this.u,
    required this.valueSize,
    required this.color,
    this.alignStart = false,
  });

  final _StatItem item;
  final double u;
  final double valueSize;
  final Color color;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          item.label,
          style: TextStyle(fontSize: 11 * u, fontWeight: FontWeight.w500),
        ),
        Text(
          item.value,
          style: TextStyle(
            fontSize: valueSize * u,
            fontWeight: FontWeight.w600,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand(this.activity, {required this.u, required this.color});

  final Activity activity;
  final double u;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(activity.type.icon, size: 14 * u, color: color),
        SizedBox(width: 4 * u),
        Text(
          'PRACHAYA RUN · ${formatDateTime(activity.startedAt).split(' · ').first}',
          style: TextStyle(
            fontSize: 10 * u,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2 * u,
          ),
        ),
      ],
    );
  }
}
