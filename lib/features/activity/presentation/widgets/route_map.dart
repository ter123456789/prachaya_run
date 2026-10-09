import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/track_point.dart';

/// Dark basemap with the route drawn as a glowing lime line.
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.segments,
    this.followLatest = false,
    this.fitPadding = const EdgeInsets.all(40),
  });

  final List<List<TrackPoint>> segments;

  /// Keep the camera on the newest point (live recording).
  /// Otherwise the camera fits the whole route.
  final bool followLatest;

  /// Extra room around the route, e.g. for overlaid controls.
  final EdgeInsets fitPadding;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  static const _fallbackCenter = LatLng(13.7563, 100.5018); // Bangkok

  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latest = _latest;
    if (widget.followLatest && _ready && latest != null) {
      _controller.move(latest, _controller.camera.zoom);
    }
  }

  LatLng? get _latest {
    for (final segment in widget.segments.reversed) {
      if (segment.isNotEmpty) return _toLatLng(segment.last);
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (final segment in widget.segments) segment.map(_toLatLng).toList(),
    ];
    final all = lines.expand((l) => l).toList();
    final canFit = !widget.followLatest && all.length > 1;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        backgroundColor: AppColors.background,
        initialCenter: _latest ?? _fallbackCenter,
        initialZoom: 16,
        initialCameraFit: canFit
            ? CameraFit.coordinates(
                coordinates: all,
                padding: widget.fitPadding,
                maxZoom: 17,
              )
            : null,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.example.prachaya_run',
        ),
        PolylineLayer(
          polylines: [
            for (final line in lines)
              if (line.length > 1) ...[
                Polyline(
                  points: line,
                  strokeWidth: 12,
                  color: AppColors.lime.withValues(alpha: 0.18),
                ),
                Polyline(points: line, strokeWidth: 4, color: AppColors.lime),
              ],
          ],
        ),
        MarkerLayer(
          markers: [
            if (all.isNotEmpty)
              Marker(
                point: all.first,
                width: 18,
                height: 18,
                child: const _StartDot(),
              ),
            if (all.length > 1)
              widget.followLatest
                  ? Marker(
                      point: all.last,
                      width: 22,
                      height: 22,
                      child: const _CurrentDot(),
                    )
                  : Marker(
                      point: all.last,
                      width: 32,
                      height: 32,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.lime,
                        size: 32,
                      ),
                    ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }

  static LatLng _toLatLng(TrackPoint p) => LatLng(p.latitude, p.longitude);
}

class _StartDot extends StatelessWidget {
  const _StartDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.background,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.lime, width: 4),
    ),
  );
}

class _CurrentDot extends StatelessWidget {
  const _CurrentDot();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.lime,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [
        BoxShadow(
          color: AppColors.lime.withValues(alpha: 0.6),
          blurRadius: 16,
          spreadRadius: 4,
        ),
      ],
    ),
  );
}
