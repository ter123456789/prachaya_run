import '../../../../core/network/token_store.dart';
import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/planned_workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_plan.dart';
import '../models/workout_json_mapper.dart';

/// Planned workouts on the device first (works signed out), synced by the
/// engine.
class OfflineFirstWorkoutRepository implements WorkoutRepository {
  OfflineFirstWorkoutRepository(
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
  Future<List<PlannedWorkout>> getAll() async {
    final list = [
      for (final r in await _store.visible(await _owner()))
        WorkoutJsonMapper.fromJson(r.id, r.data),
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Future<void> save(PlannedWorkout workout) async {
    final location = workout.location?.trim();
    final normalized = workout.copyWith(
      title: workout.title.trim(),
      location: () => location == null || location.isEmpty ? null : location,
    );
    if (!isValidWorkout(normalized)) throw const WorkoutValidationException();
    await _store.putLocal(
      workout.id,
      WorkoutJsonMapper.toJson(normalized),
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
