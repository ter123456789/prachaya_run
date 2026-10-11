import '../../../../core/network/api_client.dart';
import '../../domain/entities/activity.dart';
import '../models/activity_json_mapper.dart';
import '../models/remote_activity_summary.dart';

/// `/activities` endpoints of rinning_API (docs/api.md).
class ActivityRemoteDataSource {
  ActivityRemoteDataSource(this._api);

  final ApiClient _api;

  /// Upserts by id. The server may answer with a newer copy or a deleted
  /// one; the caller adopts what it returns.
  Future<RemoteActivitySummary> upload(
    Activity activity, {
    required DateTime updatedAt,
  }) async {
    final json = await _api.post(
      '/activities',
      ActivityJsonMapper.activityToJson(activity, updatedAt: updatedAt),
      gzipBody: true,
    );
    return ActivityJsonMapper.summaryFromJson(json! as Json);
  }

  /// Idempotent: also succeeds for unknown or already deleted ids.
  Future<void> delete(String id) => _api.delete('/activities/$id');

  /// Null when the activity is gone (deleted, or never existed).
  Future<(Activity, RemoteActivitySummary)?> download(String id) async {
    try {
      final json = await _api.get('/activities/$id') as Json;
      return (
        ActivityJsonMapper.activityFromJson(json),
        ActivityJsonMapper.summaryFromJson(json),
      );
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<RemoteChangesPage> changes({
    required String since,
    String? cursor,
    int limit = 100,
  }) async {
    final json = await _api.get(
      '/activities',
      query: {'updatedSince': since, 'limit': '$limit', 'cursor': ?cursor},
    );
    return ActivityJsonMapper.changesPageFromJson(json! as Json);
  }
}
