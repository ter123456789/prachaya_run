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

  /// Idempotent by [photoId]; the server checks the file type itself.
  Future<void> uploadPhoto({
    required String activityId,
    required String photoId,
    required List<int> bytes,
    required String filename,
    required DateTime takenAt,
  }) => _api.sendMultipart(
    'PUT',
    '/activities/$activityId/photos/$photoId',
    fileField: 'file',
    fileBytes: bytes,
    filename: filename,
    fields: {'takenAt': ActivityJsonMapper.time(takenAt)},
  );

  /// Null when the activity is gone.
  Future<List<RemotePhoto>?> photos(String activityId) async {
    try {
      final json = await _api.get('/activities/$activityId/photos') as Json;
      return [
        for (final item in (json['items']! as List<Object?>).cast<Json>())
          ActivityJsonMapper.photoFromJson(item),
      ];
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Idempotent.
  Future<void> deletePhoto(String activityId, String photoId) =>
      _api.delete('/activities/$activityId/photos/$photoId');

  /// Fetches a signed file URL (no auth).
  Future<List<int>> downloadFile(Uri url) => _api.download(url);
}
