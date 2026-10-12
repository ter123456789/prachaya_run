import '../../../../core/network/token_store.dart';
import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/shoe.dart';
import '../../domain/repositories/shoe_repository.dart';
import '../models/shoe_json_mapper.dart';

/// Shoes on the device first (works signed out), synced by the engine.
class OfflineFirstShoeRepository implements ShoeRepository {
  OfflineFirstShoeRepository(
    this._store,
    this._tokens, {
    required void Function() scheduleSync,
    DateTime Function() clock = DateTime.now,
  }) : _scheduleSync = scheduleSync,
       _clock = clock;

  final SyncedRecordStore _store;
  final TokenStore _tokens;
  final void Function() _scheduleSync;
  final DateTime Function() _clock;

  Future<String?> _owner() async => (await _tokens.read())?.userId;

  /// Two offline devices can each mark a shoe primary; the server keeps
  /// both, so the most recently edited one wins here.
  @override
  Future<List<Shoe>> getAll() async {
    final records = await _store.visible(await _owner());
    String? primaryId;
    DateTime? newest;
    for (final r in records) {
      final shoe = ShoeJsonMapper.fromJson(r.id, r.data);
      if (shoe.primary &&
          !shoe.retired &&
          (newest == null || r.updatedAt.isAfter(newest))) {
        primaryId = r.id;
        newest = r.updatedAt;
      }
    }
    return [
      for (final r in records)
        ShoeJsonMapper.fromJson(
          r.id,
          r.data,
        ).copyWith(primary: r.id == primaryId),
    ];
  }

  @override
  Future<void> save(Shoe shoe) async {
    if (!isValidShoe(shoe)) throw const ShoeValidationException();
    final owner = await _owner();
    final now = _clock();
    final normalized = shoe.copyWith(
      name: shoe.name.trim(),
      model: () {
        final m = shoe.model?.trim();
        return m == null || m.isEmpty ? null : m;
      },
      // A retired shoe cannot stay primary.
      primary: shoe.primary && !shoe.retired,
    );
    if (normalized.primary) {
      for (final other in await getAll()) {
        if (other.id != shoe.id && other.primary) {
          await _store.putLocal(
            other.id,
            ShoeJsonMapper.toJson(other.copyWith(primary: false)),
            updatedAt: now,
            ownerId: owner,
          );
        }
      }
    }
    await _store.putLocal(
      shoe.id,
      ShoeJsonMapper.toJson(normalized),
      updatedAt: now,
      ownerId: owner,
    );
    _scheduleSync();
  }

  @override
  Future<void> delete(String id) async {
    final r = await _store.get(id);
    if (r == null || r.deleted) return;
    final owner = await _owner();
    if (r.ownerId != null && r.ownerId != owner) return;
    await _store.markDeleted(id, at: _clock());
    _scheduleSync();
  }

  @override
  Future<Shoe?> primary() async {
    for (final s in await getAll()) {
      if (s.primary && !s.retired) return s;
    }
    return null;
  }
}
