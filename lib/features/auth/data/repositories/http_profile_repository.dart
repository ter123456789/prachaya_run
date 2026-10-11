import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../../../core/storage/kv_store.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// `GET/PATCH /me`, cached per account so calories work offline.
class HttpProfileRepository implements ProfileRepository {
  HttpProfileRepository(this._api, this._tokens, this._kv);

  final ApiClient _api;
  final TokenStore _tokens;
  final KvStore _kv;

  @override
  Future<UserProfile?> load() async {
    final session = await _tokens.read();
    if (session == null) return null;
    final key = _key(session.userId);
    try {
      final json = await _api.get('/me') as Map<String, Object?>;
      await _kv.write(key, json);
      return _fromJson(json);
    } on NetworkException {
      return _cached(key);
    } on ApiException {
      return _cached(key);
    }
  }

  @override
  Future<UserProfile> update({
    String? displayName,
    double? weightKg,
    bool clearWeight = false,
  }) async {
    final session = await _tokens.read();
    if (session == null) throw const ProfileUpdateException();
    try {
      final json =
          await _api.patch('/me', {
                'displayName': ?displayName,
                if (weightKg != null || clearWeight) 'weightKg': weightKg,
              })
              as Map<String, Object?>;
      await _kv.write(_key(session.userId), json);
      return _fromJson(json);
    } on NetworkException {
      throw const ProfileUpdateException(offline: true);
    } on ApiException {
      throw const ProfileUpdateException();
    }
  }

  Future<UserProfile?> _cached(String key) async {
    final json = await _kv.read(key);
    return json == null ? const UserProfile() : _fromJson(json);
  }

  static String _key(String userId) => 'profile:$userId';

  static UserProfile _fromJson(Map<String, Object?> json) => UserProfile(
    displayName: json['displayName'] as String?,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
  );
}
