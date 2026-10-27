import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/planned_route.dart';
import 'polyline_codec.dart';

/// PlannedRoute ↔ the API object (docs/api.md v1.4, Planned routes) without
/// the bookkeeping fields, which the record store keeps itself.
abstract final class RouteJsonMapper {
  static Json toJson(PlannedRoute r) => {
    'name': r.name,
    'drawn': PolylineCodec.encode(r.drawn),
    'route': r.route == null ? null : PolylineCodec.encode(r.route!),
    'closed': r.closed,
    'distanceM': r.distanceMeters,
    'score': r.score,
  };

  static PlannedRoute fromJson(String id, Json json) => PlannedRoute(
    id: id,
    name: json['name']! as String,
    drawn: PolylineCodec.decode(json['drawn']! as String),
    route: switch (json['route']) {
      final String encoded => PolylineCodec.decode(encoded),
      _ => null,
    },
    closed: json['closed'] as bool? ?? false,
    distanceMeters: (json['distanceM'] as num?)?.toDouble() ?? 0,
    score: (json['score'] as num?)?.toInt(),
  );
}
