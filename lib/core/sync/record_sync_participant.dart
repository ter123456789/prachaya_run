import '../network/api_client.dart';
import 'sync_participant.dart';
import 'synced_record_store.dart';

/// Syncs one [SyncedRecordStore] with its REST resource (docs/api.md v1.2):
/// `PUT {path}/:id` upsert, `DELETE {path}/:id`, `GET {path}?updatedSince=`.
class RecordSyncParticipant implements SyncParticipant {
  RecordSyncParticipant(this._store, this._api, {required this.path});

  static const _epoch = '1970-01-01T00:00:00.000Z';

  final SyncedRecordStore _store;
  final ApiClient _api;

  /// e.g. `/shoes`.
  final String path;

  @override
  Future<void> claimUnowned(String userId) => _store.claimUnowned(userId);

  @override
  Future<int> pendingCount(String? userId) => _store.pendingCount(userId);

  @override
  Future<bool> sync(String userId) async {
    var changed = false;
    for (final r in await _store.pending(userId)) {
      if (r.deleted) {
        await _api.delete('$path/${r.id}');
        await _store.purgeTombstone(r.id, r.updatedAt);
        continue;
      }
      final json = await _api.send(
        'PUT',
        '$path/${r.id}',
        body: {...r.data, 'id': r.id, 'updatedAt': _time(r.updatedAt)},
      );
      changed |= await _store.confirmPush(
        r.id,
        r.updatedAt,
        RemoteRecord.fromJson(json! as Json),
      );
    }

    // The cursor is per account, so switching accounts pulls everything.
    final key = '${_store.table}.updatedSince:$userId';
    final since = await _store.readCursor(key) ?? _epoch;
    String? cursor;
    String serverTime;
    do {
      final page =
          await _api.get(
                path,
                query: {
                  'updatedSince': since,
                  'limit': '100',
                  'cursor': ?cursor,
                },
              )
              as Json;
      for (final item in (page['items']! as List<Object?>).cast<Json>()) {
        changed |= await _store.applyRemote(
          RemoteRecord.fromJson(item),
          ownerId: userId,
        );
      }
      cursor = page['nextCursor'] as String?;
      serverTime = page['serverTime']! as String;
    } while (cursor != null);
    await _store.writeCursor(key, serverTime);
    return changed;
  }

  static String _time(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();
}
