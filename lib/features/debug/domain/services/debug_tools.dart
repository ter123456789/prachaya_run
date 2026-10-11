import '../entities/gps_simulation.dart';

/// Developer-only controls, wired in debug builds only (see main.dart).
abstract interface class DebugTools {
  GpsSimulation get gps;

  /// Applies right away; the next recording uses the new settings.
  void setGps(GpsSimulation value);

  /// Breaks the running simulated GPS stream, like losing signal.
  void dropGpsSignal();

  bool get offline;

  /// Makes every server call fail as if there were no internet.
  void setOffline(bool value);

  /// The next authenticated call gets `401 token_expired`, so the app
  /// refreshes its tokens against the real server.
  void expireAccessTokenOnce();

  /// Corrupts the stored refresh token and expires the access token:
  /// the next call ends the session (tests forced sign-out).
  Future<void> breakSession();

  /// Activities of the current account the server has not seen yet.
  Future<int> pendingSyncCount();

  /// Saves [count] made-up activities over the last weeks. Returns how many.
  Future<int> seedActivities({int count = 10});

  /// Deletes every activity and the sync cursor from this device (not from
  /// the server). Signing in again pulls the account's data back.
  Future<void> clearLocalData();
}
