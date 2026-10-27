import 'geo_point.dart';

/// A route to run, made by drawing a shape on the map (docs/api.md v1.4).
class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.drawn,
    this.route,
    this.closed = false,
    required this.distanceMeters,
    this.score,
  });

  final String id;
  final String name;

  /// The shape the user drew.
  final List<GeoPoint> drawn;

  /// The same shape matched to walkable ways; null until snapped (drawn
  /// signed out or offline).
  final List<GeoPoint>? route;

  /// Ends where it starts.
  final bool closed;

  /// Length of [route], or of [drawn] while not snapped.
  final double distanceMeters;

  /// 0–100: how closely [route] follows [drawn]. Null while not snapped.
  final int? score;

  bool get isSnapped => route != null;

  /// What to run: the snapped route, else the drawing itself.
  List<GeoPoint> get path => route ?? drawn;

  PlannedRoute copyWith({String? name}) => PlannedRoute(
    id: id,
    name: name ?? this.name,
    drawn: drawn,
    route: route,
    closed: closed,
    distanceMeters: distanceMeters,
    score: score,
  );
}

class RouteValidationException implements Exception {
  const RouteValidationException();
}
