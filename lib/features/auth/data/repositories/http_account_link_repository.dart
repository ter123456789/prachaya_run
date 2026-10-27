import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/linked_accounts.dart';
import '../../domain/repositories/account_link_repository.dart';

/// `/me/links` (api.md v1.6).
class HttpAccountLinkRepository implements AccountLinkRepository {
  HttpAccountLinkRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<LinkedAccounts> load() async {
    if (await _tokens.read() == null) return LinkedAccounts.none;
    try {
      final json = await _api.get('/me/links') as Map<String, Object?>;
      return LinkedAccounts(
        available: [
          for (final p in (json['available'] as List<Object?>? ?? const []))
            ?LinkProvider.values.asNameMap()[p],
        ],
        links: [
          for (final item
              in (json['items'] as List<Object?>? ?? const [])
                  .cast<Map<String, Object?>>())
            ?_link(item),
        ],
      );
    } on ApiException {
      return LinkedAccounts.none;
    } on NetworkException {
      return LinkedAccounts.none;
    }
  }

  @override
  Future<Uri> start(LinkProvider provider) async {
    try {
      final json =
          await _api.post('/me/links/${provider.name}', const {})
              as Map<String, Object?>;
      return Uri.parse(json['authorizeUrl']! as String);
    } on ApiException {
      throw const AccountLinkUnavailable();
    } on NetworkException {
      throw const AccountLinkUnavailable();
    }
  }

  @override
  Future<void> sync(LinkProvider provider) async {
    try {
      await _api.post('/me/links/${provider.name}/sync', const {});
    } on ApiException {
      // Not linked any more, or the server is busy: the poll catches up.
    } on NetworkException {
      // Offline.
    }
  }

  @override
  Future<void> unlink(LinkProvider provider) =>
      _api.delete('/me/links/${provider.name}');

  static AccountLink? _link(Map<String, Object?> json) {
    final provider = LinkProvider.values.asNameMap()[json['provider']];
    if (provider == null) return null;
    final last = json['lastImportAt'] as String?;
    return AccountLink(
      provider: provider,
      status:
          LinkStatus.values.asNameMap()[json['status']] ?? LinkStatus.expired,
      linkedAt: DateTime.parse(json['linkedAt']! as String).toLocal(),
      lastImportAt: last == null ? null : DateTime.parse(last).toLocal(),
    );
  }
}
