import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_participant.dart';
import '../../domain/entities/user_profile.dart';
import '../models/profile_json_mapper.dart';
import 'profile_store.dart';

/// Pushes an edited profile with `PATCH /me` (every field, so clearing one
/// reaches the server), otherwise pulls `GET /me`.
class ProfileSync implements SyncParticipant {
  ProfileSync(
    this._store,
    this._api, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  final ProfileStore _store;
  final ApiClient _api;
  final DateTime Function() _clock;

  /// A profile made signed out fills the fields the account has not set.
  @override
  Future<void> claimUnowned(String userId) async {
    final local = await _store.read(null);
    if (local == null) return;
    final account = await _store.read(userId);
    await _store.writeEdit(
      userId,
      local.profile.mergedOver(account?.profile ?? const UserProfile()),
      at: _clock(),
    );
    await _store.remove(null);
  }

  @override
  Future<int> pendingCount(String? userId) async {
    final stored = await _store.read(userId);
    if (stored == null) return 0;
    return stored.dirty && !(userId == null && stored.profile.isEmpty) ? 1 : 0;
  }

  @override
  Future<bool> sync(String userId) async {
    final stored = await _store.read(userId);
    if (stored != null && stored.dirty) {
      final json =
          await _api.patch('/me', ProfileJsonMapper.toJson(stored.profile))
              as Json;
      final again = await _store.read(userId);
      // Edited again meanwhile: that edit is pushed on the next run.
      if (again?.editedAtMs != stored.editedAtMs) return false;
      final server = ProfileJsonMapper.fromJson(json);
      await _store.writeClean(userId, server);
      return server != stored.profile;
    }
    final server = ProfileJsonMapper.fromJson(await _api.get('/me') as Json);
    final again = await _store.read(userId);
    if (again != null && again.dirty) return false;
    await _store.writeClean(userId, server);
    return server != stored?.profile;
  }
}
