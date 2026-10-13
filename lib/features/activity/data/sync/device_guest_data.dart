import '../../../../core/sync/synced_record_store.dart';
import '../../../auth/data/sync/profile_store.dart';
import '../../../auth/domain/entities/guest_data_summary.dart';
import '../../../auth/domain/repositories/guest_data_repository.dart';
import '../../domain/entities/activity.dart';
import '../../domain/services/best_efforts.dart';
import '../datasources/activity_local_data_source.dart';
import '../datasources/photo_local_data_source.dart';
import 'activity_sync_engine.dart';

/// Unowned rows (`owner_id IS NULL`) are the guest data. Merging claims them
/// through the sync engine; keeping them parks them under the device-only
/// owner so no account sees or sends them.
class DeviceGuestData implements GuestDataRepository {
  DeviceGuestData({
    required ActivityLocalDataSource activities,
    required PhotoLocalDataSource photos,
    required SyncedRecordStore shoes,
    required SyncedRecordStore workouts,
    required ProfileStore profiles,
    required ActivitySyncEngine sync,
  }) : _activities = activities,
       _photos = photos,
       _shoes = shoes,
       _workouts = workouts,
       _profiles = profiles,
       _sync = sync;

  final ActivityLocalDataSource _activities;
  final PhotoLocalDataSource _photos;
  final SyncedRecordStore _shoes;
  final SyncedRecordStore _workouts;
  final ProfileStore _profiles;
  final ActivitySyncEngine _sync;

  List<SyncedRecordStore> get _records => [_shoes, _workouts];

  @override
  Future<GuestDataSummary> summary() async {
    final summaries = await _activities.summaries(ownerId: null);
    final tracks = <Activity>[
      for (final s in summaries) ?await _activities.activity(s.id),
    ];
    final profile = await _profiles.read(null);
    return GuestDataSummary(
      activityCount: summaries.length,
      distanceMeters: summaries.fold(0, (sum, a) => sum + a.distanceMeters),
      movingTime: summaries.fold(Duration.zero, (sum, a) => sum + a.movingTime),
      bests: PersonalBests.from(tracks),
      shoeCount: (await _shoes.visible(null)).length,
      workoutCount: (await _workouts.visible(null)).length,
      hasProfile: profile != null && !profile.profile.isEmpty,
    );
  }

  @override
  Future<void> merge(String userId) async {
    await _sync.claimGuestData(userId);
    _sync.schedule();
  }

  @override
  Future<void> keepOnDevice() async {
    await _activities.parkUnowned();
    await _photos.parkUnowned();
    for (final r in _records) {
      await r.parkUnowned();
    }
    await _profiles.park();
  }

  @override
  Future<void> restore() async {
    await _activities.restoreDeviceOnly();
    await _photos.restoreDeviceOnly();
    for (final r in _records) {
      await r.restoreDeviceOnly();
    }
    await _profiles.restoreParked();
  }
}
