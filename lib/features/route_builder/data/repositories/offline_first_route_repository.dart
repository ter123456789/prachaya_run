import '../../../../core/network/token_store.dart';
import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/planned_route.dart';
import '../../domain/repositories/route_repository.dart';
import '../models/route_json_mapper.dart';

/// Planned routes on the device first (works signed out), synced by the
/// engine.
class OfflineFirstRouteRepository implements RouteRepository {
  OfflineFirstRouteRepository(
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

  @override
  Future<List<PlannedRoute>> getAll() async {
    final list = [
      for (final r in await _store.visible(await _owner()))
        RouteJsonMapper.fromJson(r.id, r.data),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<void> save(PlannedRoute route) async {
    final normalized = route.copyWith(name: route.name.trim());
    if (normalized.name.isEmpty ||
        normalized.name.length > 60 ||
        normalized.drawn.length < 2) {
      throw const RouteValidationException();
    }
    await _store.putLocal(
      route.id,
      RouteJsonMapper.toJson(normalized),
      updatedAt: _clock(),
      ownerId: await _owner(),
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
}
