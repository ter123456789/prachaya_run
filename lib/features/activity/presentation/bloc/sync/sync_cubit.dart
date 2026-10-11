import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/activity_sync.dart';

final class SyncState extends Equatable {
  const SyncState({
    this.syncing = false,
    this.lastOutcome,
    this.lastSyncedAt,
    this.revision = 0,
    this.pending = 0,
  });

  final bool syncing;
  final SyncOutcome? lastOutcome;
  final DateTime? lastSyncedAt;

  /// Bumped whenever a sync changed local data; lists reload on change.
  final int revision;

  /// Local changes not yet on the server.
  final int pending;

  SyncState copyWith({
    bool? syncing,
    SyncOutcome? lastOutcome,
    DateTime? lastSyncedAt,
    int? revision,
    int? pending,
  }) => SyncState(
    syncing: syncing ?? this.syncing,
    lastOutcome: lastOutcome ?? this.lastOutcome,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    revision: revision ?? this.revision,
    pending: pending ?? this.pending,
  );

  @override
  List<Object?> get props => [
    syncing,
    lastOutcome,
    lastSyncedAt,
    revision,
    pending,
  ];
}

class SyncCubit extends Cubit<SyncState> {
  SyncCubit(this._sync, {DateTime Function() clock = DateTime.now})
    : _clock = clock,
      super(const SyncState()) {
    _changes = _sync.changes.listen(
      (_) => emit(state.copyWith(revision: state.revision + 1)),
    );
  }

  final ActivitySync _sync;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _changes;

  Future<SyncOutcome> sync() async {
    emit(state.copyWith(syncing: true));
    final outcome = await _sync.sync();
    if (isClosed) return outcome;
    final pending = await _sync.pendingCount();
    if (isClosed) return outcome;
    emit(
      state.copyWith(
        syncing: false,
        lastOutcome: outcome,
        lastSyncedAt: outcome == SyncOutcome.synced ? _clock() : null,
        pending: pending,
      ),
    );
    return outcome;
  }

  /// Re-counts local changes waiting for the server.
  Future<void> refreshPending() async {
    final pending = await _sync.pendingCount();
    if (!isClosed) emit(state.copyWith(pending: pending));
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
