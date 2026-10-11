enum SyncOutcome {
  /// Local and server data now match.
  synced,

  /// No account is signed in; nothing was sent.
  signedOut,

  /// The server could not be reached. Local data is kept and retried later.
  offline,

  /// The server answered with an unexpected error.
  failed,
}

/// Two-way sync between the on-device store and the server.
/// Activities are always saved locally first; this pushes pending changes
/// and pulls changes made on other devices.
abstract interface class ActivitySync {
  /// Runs one sync. Calls made while a sync is running join it.
  Future<SyncOutcome> sync();

  /// Fires after a sync changed the local data (e.g. pulled an activity
  /// from another device), so lists can reload.
  Stream<void> get changes;
}
