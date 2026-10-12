/// Something besides activities that the sync engine pushes and pulls for
/// the signed-in account (profile, shoes, planned workouts).
///
/// Runs after activities and photos, in the same sync. Throws the
/// `ApiClient` exceptions; the engine turns them into an outcome.
abstract interface class SyncParticipant {
  /// Gives data made while signed out to [userId] (like activities).
  Future<void> claimUnowned(String userId);

  /// Local changes the server has not seen. [userId] null = signed out.
  Future<int> pendingCount(String? userId);

  /// Pushes local changes, then pulls the server's. Returns whether local
  /// data changed.
  Future<bool> sync(String userId);
}
