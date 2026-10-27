import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/linked_accounts.dart';
import '../../domain/repositories/account_link_repository.dart';
import '../../domain/services/external_browser.dart';

final class LinkedAccountsState extends Equatable {
  const LinkedAccountsState({
    this.accounts = LinkedAccounts.none,
    this.busy,
    this.failed = false,
  });

  final LinkedAccounts accounts;

  /// The brand being linked or unlinked.
  final LinkProvider? busy;

  /// The last link attempt could not start (shown once).
  final bool failed;

  /// Brands to show: what the server offers plus anything still linked.
  List<LinkProvider> get providers => {
    ...accounts.available,
    ...accounts.links.map((l) => l.provider),
  }.toList();

  @override
  List<Object?> get props => [accounts.available, accounts.links, busy, failed];
}

/// Watch brand accounts the server imports from (Strava-style). Linking
/// happens in the browser; coming back to the app reloads the links and asks
/// the server for new workouts.
class LinkedAccountsCubit extends Cubit<LinkedAccountsState> {
  LinkedAccountsCubit(this._repository, this._browser)
    : super(const LinkedAccountsState());

  final AccountLinkRepository? _repository;
  final ExternalBrowser? _browser;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final accounts = await repository.load();
    if (!isClosed) emit(LinkedAccountsState(accounts: accounts));
  }

  /// On resume: links may have changed in the browser, and linked brands
  /// may have new workouts.
  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;
    await load();
    for (final link in state.accounts.links) {
      if (link.status == LinkStatus.ok) await repository.sync(link.provider);
    }
  }

  Future<void> link(LinkProvider provider) async {
    final repository = _repository;
    final browser = _browser;
    if (repository == null || browser == null) return;
    emit(LinkedAccountsState(accounts: state.accounts, busy: provider));
    try {
      final url = await repository.start(provider);
      final opened = await browser.open(url);
      if (!isClosed) {
        emit(LinkedAccountsState(accounts: state.accounts, failed: !opened));
      }
    } on AccountLinkUnavailable {
      if (!isClosed) {
        emit(LinkedAccountsState(accounts: state.accounts, failed: true));
      }
    }
  }

  Future<void> unlink(LinkProvider provider) async {
    final repository = _repository;
    if (repository == null) return;
    emit(LinkedAccountsState(accounts: state.accounts, busy: provider));
    try {
      await repository.unlink(provider);
    } catch (_) {
      // Offline: the link stays; the list below shows it as it is.
    }
    await load();
  }
}
