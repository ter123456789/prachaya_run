import '../../../../core/network/api_client.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/repositories/route_snapper.dart';
import '../models/polyline_codec.dart';

/// `POST /routes/snap` (docs/api.md v1.4). The server runs the map matcher
/// (Valhalla), so signed out there is nothing to call.
class HttpRouteSnapper implements RouteSnapper {
  HttpRouteSnapper(this._api);

  final ApiClient _api;

  @override
  Future<SnappedPath> snap(List<GeoPoint> shape) async {
    try {
      final json =
          await _api.post('/routes/snap', {
                'shape': PolylineCodec.encode(shape),
              })
              as Map<String, Object?>;
      return SnappedPath(
        PolylineCodec.decode(json['route']! as String),
        (json['distanceM']! as num).toDouble(),
      );
    } on ApiException catch (e) {
      throw RouteSnapException(switch ((e.status, e.code)) {
        (401, _) => RouteSnapError.signedOut,
        (422, _) => RouteSnapError.noRoute,
        (400, _) => RouteSnapError.tooLong,
        (_, 'provider_not_configured') => RouteSnapError.notConfigured,
        _ => RouteSnapError.unavailable,
      });
    } on NetworkException {
      throw const RouteSnapException(RouteSnapError.unavailable);
    }
  }
}
