import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/services/uuid.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/planned_route.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/repositories/route_snapper.dart';
import '../../domain/services/route_fit.dart';
import '../../domain/services/route_geometry.dart';
import '../../domain/usecases/snap_drawing.dart';

/// Finger on the map draws; otherwise it moves the map.
enum DrawTool { draw, pan }

enum SnapStatus { idle, snapping, snapped, failed }

final class RouteDrawState extends Equatable {
  const RouteDrawState({
    this.strokes = const [],
    this.tool = DrawTool.draw,
    this.closed = true,
    this.status = SnapStatus.idle,
    this.plan,
    this.error,
    this.editing,
  });

  /// Finger strokes in drawing order; joined into one shape.
  final List<List<GeoPoint>> strokes;
  final DrawTool tool;

  /// Run back to the start.
  final bool closed;
  final SnapStatus status;

  /// The snapped result for the current strokes; cleared when they change.
  final RoutePlan? plan;

  /// Why the last snap failed.
  final RouteSnapError? error;

  /// The saved route being edited, if any.
  final PlannedRoute? editing;

  bool get hasDrawing => strokes.any((s) => s.length > 1);

  /// The drawing's length before snapping.
  double get drawnMeters => pathLength(drawnShape(strokes, closed: closed));

  RouteDrawState copyWith({
    List<List<GeoPoint>>? strokes,
    DrawTool? tool,
    bool? closed,
    SnapStatus? status,
    RoutePlan? Function()? plan,
    RouteSnapError? Function()? error,
  }) => RouteDrawState(
    strokes: strokes ?? this.strokes,
    tool: tool ?? this.tool,
    closed: closed ?? this.closed,
    status: status ?? this.status,
    plan: plan == null ? this.plan : plan(),
    error: error == null ? this.error : error(),
    editing: editing,
  );

  @override
  List<Object?> get props => [
    strokes,
    tool,
    closed,
    status,
    plan,
    error,
    editing,
  ];
}

/// Draw a route: finger strokes on the map → snapped route → saved.
class RouteDrawCubit extends Cubit<RouteDrawState> {
  RouteDrawCubit(this._snap, this._routes, {PlannedRoute? editing})
    : super(_initial(editing));

  final SnapDrawing _snap;
  final RouteRepository _routes;

  static RouteDrawState _initial(PlannedRoute? r) {
    if (r == null) return const RouteDrawState();
    // A closed drawing repeats its start; drop it so re-closing adds it once.
    final drawn =
        r.closed && r.drawn.length > 2 && r.drawn.last == r.drawn.first
        ? r.drawn.sublist(0, r.drawn.length - 1)
        : r.drawn;
    final route = r.route;
    return RouteDrawState(
      strokes: [drawn],
      tool: DrawTool.pan,
      closed: r.closed,
      status: route == null ? SnapStatus.idle : SnapStatus.snapped,
      plan: route == null
          ? null
          : RoutePlan(
              drawn: r.drawn,
              route: route,
              distanceMeters: r.distanceMeters,
              fit: fitRoute(r.drawn, route),
            ),
      editing: r,
    );
  }

  void setTool(DrawTool tool) => emit(state.copyWith(tool: tool));

  void startStroke(GeoPoint p) => _edit([
    ...state.strokes,
    [p],
  ]);

  void extendStroke(GeoPoint p) {
    if (state.strokes.isEmpty) return startStroke(p);
    _edit([
      ...state.strokes.sublist(0, state.strokes.length - 1),
      [...state.strokes.last, p],
    ]);
  }

  /// A tap without movement leaves a one-point stroke; drop it.
  void endStroke() {
    if (state.strokes.isNotEmpty && state.strokes.last.length < 2) {
      _edit(state.strokes.sublist(0, state.strokes.length - 1));
    }
  }

  void undo() {
    if (state.strokes.isEmpty) return;
    _edit(state.strokes.sublist(0, state.strokes.length - 1));
  }

  void clear() => _edit(const []);

  void setClosed(bool closed) => emit(
    state.copyWith(
      closed: closed,
      status: SnapStatus.idle,
      plan: () => null,
      error: () => null,
    ),
  );

  void _edit(List<List<GeoPoint>> strokes) => emit(
    state.copyWith(
      strokes: strokes,
      status: SnapStatus.idle,
      plan: () => null,
      error: () => null,
    ),
  );

  Future<void> snap() async {
    if (!state.hasDrawing || state.status == SnapStatus.snapping) return;
    final strokes = state.strokes;
    emit(state.copyWith(status: SnapStatus.snapping, error: () => null));
    try {
      final plan = await _snap(strokes, closed: state.closed);
      // Drawn on while waiting: that answer is for an old shape.
      if (isClosed || state.strokes != strokes) return;
      emit(state.copyWith(status: SnapStatus.snapped, plan: () => plan));
    } on RouteSnapException catch (e) {
      if (isClosed || state.strokes != strokes) return;
      emit(state.copyWith(status: SnapStatus.failed, error: () => e.error));
    } on RouteValidationException {
      if (isClosed) return;
      emit(state.copyWith(status: SnapStatus.idle));
    }
  }

  /// Saves the snapped route, or the drawing alone when it is not snapped
  /// (signed out, offline); it can be snapped later. Throws
  /// [RouteValidationException] for an empty name.
  Future<PlannedRoute> save(String name) async {
    final plan =
        state.plan ??
        RoutePlan.unsnapped(drawnShape(state.strokes, closed: state.closed));
    final route = PlannedRoute(
      id: state.editing?.id ?? uuidV4(),
      name: name,
      drawn: plan.drawn,
      route: plan.route,
      closed: state.closed,
      distanceMeters: plan.distanceMeters,
      score: plan.fit?.score,
    );
    await _routes.save(route);
    return route;
  }
}
