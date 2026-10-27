import '../entities/linked_accounts.dart';

/// The brand cannot be linked right now (not set up on the server, or
/// offline).
class AccountLinkUnavailable implements Exception {
  const AccountLinkUnavailable();
}

/// Strava-style links to watch brand accounts: the server imports their
/// workouts, which reach the app through the normal sync.
abstract interface class AccountLinkRepository {
  /// [LinkedAccounts.none] when signed out or offline.
  Future<LinkedAccounts> load();

  /// The brand's sign-in page to open in the browser.
  Future<Uri> start(LinkProvider provider);

  /// Asks the server to look for new workouts now.
  Future<void> sync(LinkProvider provider);

  Future<void> unlink(LinkProvider provider);
}
