import '../../domain/entities/user_profile.dart';

typedef Json = Map<String, Object?>;

/// UserProfile ↔ the `/me` object (docs/api.md). The device copy in `kv`
/// uses the same fields plus `_dirty` / `_editedAt`.
abstract final class ProfileJsonMapper {
  static Json toJson(UserProfile p) => {
    'displayName': p.displayName,
    'weightKg': p.weightKg,
    'heightCm': p.heightCm,
    'birthYear': p.birthYear,
    'maxHrBpm': p.maxHrBpm,
  };

  static UserProfile fromJson(Json json) => UserProfile(
    displayName: json['displayName'] as String?,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    birthYear: (json['birthYear'] as num?)?.toInt(),
    maxHrBpm: (json['maxHrBpm'] as num?)?.toInt(),
  );
}
