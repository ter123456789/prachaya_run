import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../activity/presentation/bloc/dashboard/dashboard_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/planned_route.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/repositories/route_snapper.dart';
import '../../domain/usecases/snap_drawing.dart';
import '../bloc/route_draw_cubit.dart';
import '../bloc/routes_cubit.dart';
import '../route_labels.dart';

/// Draw a shape on the map; the server matches it to walkable ways and the
/// panel shows the distance and how closely the route follows the drawing.
/// Detours around blocks show in amber.
class RouteDrawPage extends StatelessWidget {
  const RouteDrawPage({super.key});

  /// [route] opens a saved route to view, redraw or delete.
  static Route<void> route({PlannedRoute? route}) => MaterialPageRoute(
    builder: (context) => BlocProvider(
      create: (_) => RouteDrawCubit(
        SnapDrawing(context.read<RouteSnapper>()),
        context.read<RouteRepository>(),
        editing: route,
      ),
      child: const RouteDrawPage(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Landscape with room: the panel sits beside the map.
          final side =
              constraints.maxWidth >= 600 &&
              constraints.maxWidth > constraints.maxHeight;
          final panel = SafeArea(
            top: side,
            left: !side,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: side ? 360 : 480),
                child: const _Panel(),
              ),
            ),
          );
          return Stack(
            children: [
              const Positioned.fill(child: _DrawMap()),
              const Positioned(left: 0, right: 0, top: 0, child: _TopBar()),
              if (side)
                Positioned(top: 0, right: 0, bottom: 0, child: panel)
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(child: panel),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RouteDrawCubit>();
    final state = context.watch<RouteDrawCubit>().state;
    final editing = state.editing;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'กลับ',
              size: 44,
              filled: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            CircleIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'ย้อนเส้นล่าสุด',
              size: 44,
              filled: true,
              onPressed: state.strokes.isEmpty ? null : cubit.undo,
            ),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.layers_clear_outlined,
              tooltip: 'ล้างรูป',
              size: 44,
              filled: true,
              onPressed: state.strokes.isEmpty ? null : cubit.clear,
            ),
            if (editing != null) ...[
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'ลบเส้นทาง',
                size: 44,
                filled: true,
                iconColor: AppColors.negative,
                onPressed: () => _confirmDelete(context, editing),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PlannedRoute route) async {
    final routes = context.read<RoutesCubit>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบเส้นทางนี้?'),
        content: Text(route.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ลบ',
              style: TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await routes.delete(route.id);
    navigator.pop();
  }
}

class _DrawMap extends StatefulWidget {
  const _DrawMap();

  @override
  State<_DrawMap> createState() => _DrawMapState();
}

class _DrawMapState extends State<_DrawMap> {
  static const _bangkok = LatLng(13.7563, 100.5018);

  /// Finger moves shorter than this (logical px) add no point.
  static const _minStep = 6.0;

  final _controller = MapController();
  Offset? _lastPoint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where the last run started, else Bangkok.
  LatLng _home() {
    final latest = context.read<DashboardCubit>().state.latest;
    for (final s in latest?.segments ?? const []) {
      if (s.isNotEmpty) return LatLng(s.first.latitude, s.first.longitude);
    }
    return _bangkok;
  }

  GeoPoint _geo(Offset local) {
    final p = _controller.camera.screenOffsetToLatLng(local);
    return GeoPoint(p.latitude, p.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RouteDrawCubit>();
    final state = context.watch<RouteDrawCubit>().state;
    final plan = state.plan;
    final route = plan?.route;
    final fitTo = [
      for (final p in state.editing?.path ?? const <GeoPoint>[]) _ll(p),
    ];

    final drawnLines = [
      for (final s in state.strokes)
        if (s.length > 1) s.map(_ll).toList(),
    ];
    final allDrawn = drawnLines.expand((l) => l).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            backgroundColor: AppColors.background,
            initialCenter: _home(),
            initialZoom: 15,
            initialCameraFit: fitTo.length > 1
                ? CameraFit.coordinates(
                    coordinates: fitTo,
                    padding: const EdgeInsets.fromLTRB(40, 100, 40, 280),
                    maxZoom: 17,
                  )
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
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
                // The drawing: solid while drawing, a faint guide once snapped.
                for (final line in drawnLines)
                  Polyline(
                    points: line,
                    strokeWidth: route == null ? 4 : 3,
                    color: route == null
                        ? AppColors.mintIce
                        : AppColors.textMuted,
                    pattern: route == null
                        ? const StrokePattern.solid()
                        : StrokePattern.dashed(segments: const [8, 8]),
                  ),
                // Where a closed drawing will run back to its start.
                if (route == null && state.closed && allDrawn.length > 2)
                  Polyline(
                    points: [allDrawn.last, allDrawn.first],
                    strokeWidth: 3,
                    color: AppColors.textMuted,
                    pattern: StrokePattern.dashed(segments: const [6, 8]),
                  ),
                if (route != null) ...[
                  Polyline(
                    points: route.map(_ll).toList(),
                    strokeWidth: 12,
                    color: AppColors.lime.withValues(alpha: 0.18),
                  ),
                  Polyline(
                    points: route.map(_ll).toList(),
                    strokeWidth: 4,
                    color: AppColors.lime,
                  ),
                  for (final (start, end)
                      in plan!.fit?.offShape ?? const <(int, int)>[])
                    Polyline(
                      points: route.sublist(start, end + 1).map(_ll).toList(),
                      strokeWidth: 5,
                      color: AppColors.negative,
                    ),
                ],
              ],
            ),
            MarkerLayer(
              markers: [
                if ((route ?? state.strokes.firstOrNull) case [
                  final first,
                  ...,
                ])
                  Marker(
                    point: _ll(first),
                    width: 18,
                    height: 18,
                    child: const _StartDot(),
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
        ),
        // Drawing mode: the finger draws instead of moving the map.
        if (state.tool == DrawTool.draw)
          Positioned.fill(
            child: Semantics(
              label: 'พื้นที่วาดเส้นทาง',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  _lastPoint = d.localPosition;
                  HapticFeedback.selectionClick();
                  cubit.startStroke(_geo(d.localPosition));
                },
                onPanUpdate: (d) {
                  final last = _lastPoint;
                  if (last != null &&
                      (d.localPosition - last).distance < _minStep) {
                    return;
                  }
                  _lastPoint = d.localPosition;
                  cubit.extendStroke(_geo(d.localPosition));
                },
                onPanEnd: (_) {
                  _lastPoint = null;
                  cubit.endStroke();
                },
              ),
            ),
          ),
      ],
    );
  }

  static LatLng _ll(GeoPoint p) => LatLng(p.latitude, p.longitude);
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

class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RouteDrawCubit>();
    final state = context.watch<RouteDrawCubit>().state;
    final units = context.units;
    final plan = state.plan;
    final fit = plan?.fit;
    final snapping = state.status == SnapStatus.snapping;
    final meters = plan?.distanceMeters ?? state.drawnMeters;

    final message = switch (state) {
      RouteDrawState(error: final e?) => RouteLabels.snapError(e),
      RouteDrawState(hasDrawing: false, tool: DrawTool.draw) =>
        'ลากนิ้วบนแผนที่เพื่อวาดรูป วาดต่อได้หลายเส้น',
      RouteDrawState(hasDrawing: false) =>
        'เลื่อนแผนที่ไปยังที่ที่อยากวิ่ง แล้วกด "วาด"',
      _ => null,
    };

    return GlassCard(
      blur: true,
      strong: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillTabs<DrawTool>(
            items: DrawTool.values,
            selected: state.tool,
            onChanged: cubit.setTool,
            labelOf: (t) => switch (t) {
              DrawTool.draw => 'วาด',
              DrawTool.pan => 'เลื่อนแผนที่',
            },
            iconOf: (t) => switch (t) {
              DrawTool.draw => Icons.gesture_rounded,
              DrawTool.pan => Icons.pan_tool_alt_outlined,
            },
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('วนกลับจุดเริ่ม', style: AppText.label),
            value: state.closed,
            onChanged: cubit.setClosed,
          ),
          if (state.hasDrawing)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(units.distance(meters), style: AppText.metricMd),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(units.distanceUnit, style: AppText.caption),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    fit == null
                        ? RouteLabels.notSnapped
                        : [
                            RouteLabels.fit(fit.score),
                            if (fit.offShape.isNotEmpty)
                              RouteLabels.detours(fit.offShape.length),
                          ].join(' • '),
                    style: AppText.label.copyWith(
                      color: fit == null
                          ? AppColors.textMuted
                          : AppColors.secondary,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: AppText.caption.copyWith(
                color: state.error == null
                    ? AppColors.textSecondary
                    : AppColors.negative,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (state.status != SnapStatus.snapped) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.hasDrawing && !snapping
                        ? () => _save(context)
                        : null,
                    child: const Text('บันทึกรูปวาด'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: state.hasDrawing && !snapping
                        ? cubit.snap
                        : null,
                    child: snapping
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('หาเส้นทาง'),
                  ),
                ),
              ] else
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(context),
                    child: const Text('บันทึกเส้นทาง'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<RouteDrawCubit>();
    final routes = context.read<RoutesCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await _askName(context, cubit.state.editing?.name ?? '');
    if (name == null) return;
    try {
      await cubit.save(name);
    } on RouteValidationException {
      messenger.showSnackBar(
        const SnackBar(content: Text('ตั้งชื่อเส้นทาง (ไม่เกิน 60 ตัวอักษร)')),
      );
      return;
    }
    await routes.load();
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('บันทึกเส้นทางแล้ว')));
  }

  static Future<String?> _askName(BuildContext context, String initial) =>
      showDialog<String>(
        context: context,
        builder: (_) => _NameDialog(initial),
      );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog(this.initial);

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ตั้งชื่อเส้นทาง'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 60,
      decoration: const InputDecoration(hintText: 'เช่น หัวใจรอบสวนลุม'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('บันทึก'),
      ),
    ],
  );
}
