/// A watch brand whose cloud the server imports from (api.md v1.6).
enum LinkProvider { polar, garmin }

enum LinkStatus {
  ok,

  /// The brand rejected the server's tokens: link again.
  expired,
  revoked,
}

class AccountLink {
  const AccountLink({
    required this.provider,
    required this.status,
    required this.linkedAt,
    this.lastImportAt,
  });

  final LinkProvider provider;
  final LinkStatus status;
  final DateTime linkedAt;
  final DateTime? lastImportAt;

  @override
  bool operator ==(Object other) =>
      other is AccountLink &&
      other.provider == provider &&
      other.status == status &&
      other.linkedAt == linkedAt &&
      other.lastImportAt == lastImportAt;

  @override
  int get hashCode => Object.hash(provider, status, linkedAt, lastImportAt);
}

class LinkedAccounts {
  const LinkedAccounts({this.available = const [], this.links = const []});

  static const none = LinkedAccounts();

  /// Brands this server can link (configured there).
  final List<LinkProvider> available;
  final List<AccountLink> links;

  AccountLink? linkOf(LinkProvider provider) {
    for (final l in links) {
      if (l.provider == provider) return l;
    }
    return null;
  }
}
