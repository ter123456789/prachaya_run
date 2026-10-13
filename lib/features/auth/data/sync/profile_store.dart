import '../../../../core/storage/kv_store.dart';
import '../../domain/entities/user_profile.dart';
import '../models/profile_json_mapper.dart';

/// A stored profile and whether the server has seen it.
class StoredProfile {
  const StoredProfile(this.profile, {required this.dirty, this.editedAtMs});

  final UserProfile profile;
  final bool dirty;
  final int? editedAtMs;
}

/// Profiles in `kv`: `profile:<userId>` per account and `profile:local`
/// for the device while signed out. Rows cached by v3 (server copies
/// without `_dirty`) read as clean.
class ProfileStore {
  ProfileStore(this._kv);

  final KvStore _kv;

  static String _key(String? userId) => 'profile:${userId ?? 'local'}';

  Future<StoredProfile?> read(String? userId) async {
    final json = await _kv.read(_key(userId));
    if (json == null) return null;
    return StoredProfile(
      ProfileJsonMapper.fromJson(json),
      dirty: json['_dirty'] == true,
      editedAtMs: json['_editedAt'] as int?,
    );
  }

  /// A local edit, waiting to be pushed.
  Future<void> writeEdit(
    String? userId,
    UserProfile profile, {
    required DateTime at,
  }) => _kv.write(_key(userId), {
    ...ProfileJsonMapper.toJson(profile),
    '_dirty': true,
    '_editedAt': at.millisecondsSinceEpoch,
  });

  /// The server's copy.
  Future<void> writeClean(String userId, UserProfile profile) =>
      _kv.write(_key(userId), ProfileJsonMapper.toJson(profile));

  Future<void> remove(String? userId) => _kv.remove(_key(userId));

  static const _parkedKey = 'profile:device-only';

  /// Sign-in "keep on this device": the signed-out profile is set aside so
  /// the account neither shows nor claims it.
  Future<void> park() => _move(_key(null), _parkedKey);

  /// Signed out again: the set-aside profile is the device's own again.
  Future<void> restoreParked() => _move(_parkedKey, _key(null));

  Future<void> _move(String from, String to) async {
    final json = await _kv.read(from);
    if (json == null) return;
    await _kv.write(to, json);
    await _kv.remove(from);
  }
}
