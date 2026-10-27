import '../entities/planned_route.dart';

abstract interface class RouteRepository {
  /// The current account's routes (or the device's when signed out), by
  /// name.
  Future<List<PlannedRoute>> getAll();

  /// Adds or replaces a route. Throws [RouteValidationException] for an
  /// empty name or fewer than two points.
  Future<void> save(PlannedRoute route);

  Future<void> delete(String id);
}
