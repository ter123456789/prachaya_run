import '../entities/guest_data_summary.dart';

/// Data recorded on this device while signed out, and what a sign-in does
/// with it. Nothing is merged without the user's choice (Stitch 07.1).
abstract interface class GuestDataRepository {
  /// Activities, shoes, plans and profile made signed out and not yet
  /// given to an account. [GuestDataSummary.empty] when there are none.
  Future<GuestDataSummary> summary();

  /// Gives all of it to [userId] and syncs it up.
  Future<void> merge(String userId);

  /// Keeps it on this device only: hidden from the signed-in account and
  /// never sent. It comes back when the account signs out.
  Future<void> keepOnDevice();

  /// Signed out: device-only data is the device's own again.
  Future<void> restore();
}
