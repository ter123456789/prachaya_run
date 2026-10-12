import '../../../../core/network/token_store.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/services/profile_validation.dart';
import '../sync/profile_store.dart';

/// The profile lives on the device (one copy per account, plus the
/// device's own while signed out) and is pushed to `PATCH /me` by
/// [ProfileSync].
class LocalFirstProfileRepository implements ProfileRepository {
  LocalFirstProfileRepository(
    this._store,
    this._tokens, {
    required void Function() scheduleSync,
    DateTime Function() clock = DateTime.now,
  }) : _scheduleSync = scheduleSync,
       _clock = clock;

  final ProfileStore _store;
  final TokenStore _tokens;
  final void Function() _scheduleSync;
  final DateTime Function() _clock;

  @override
  Future<UserProfile> load() async {
    final userId = (await _tokens.read())?.userId;
    final local = await _store.read(null);
    if (userId == null) return local?.profile ?? const UserProfile();
    final account = await _store.read(userId);
    final profile = account?.profile ?? const UserProfile();
    // Made signed out and not claimed yet: it joins this account next sync.
    return local == null ? profile : local.profile.mergedOver(profile);
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    final name = profile.displayName?.trim();
    final normalized = UserProfile(
      displayName: name == null || name.isEmpty ? null : name,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      birthYear: profile.birthYear,
      maxHrBpm: profile.maxHrBpm,
    );
    final invalid = validateProfile(normalized, currentYear: _clock().year);
    if (invalid.isNotEmpty) throw ProfileValidationException(invalid);
    final userId = (await _tokens.read())?.userId;
    await _store.writeEdit(userId, normalized, at: _clock());
    // The edit already includes anything shown from the unclaimed copy.
    if (userId != null) await _store.remove(null);
    _scheduleSync();
    return normalized;
  }
}
