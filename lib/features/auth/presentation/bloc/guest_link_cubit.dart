import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/guest_data_summary.dart';
import '../../domain/repositories/guest_data_repository.dart';

enum GuestLinkStatus { loading, ready, working, merged, kept }

final class GuestLinkState extends Equatable {
  const GuestLinkState({
    this.status = GuestLinkStatus.loading,
    this.summary = GuestDataSummary.empty,
  });

  final GuestLinkStatus status;
  final GuestDataSummary summary;

  bool get isDone =>
      status == GuestLinkStatus.merged || status == GuestLinkStatus.kept;

  @override
  List<Object?> get props => [status, summary];
}

/// Stitch 07.1: after a sign-in, the user decides what happens to the data
/// recorded on this device while signed out.
class GuestLinkCubit extends Cubit<GuestLinkState> {
  GuestLinkCubit(this._guest) : super(const GuestLinkState());

  final GuestDataRepository _guest;

  Future<void> load() async {
    final summary = await _guest.summary();
    if (isClosed) return;
    emit(GuestLinkState(status: GuestLinkStatus.ready, summary: summary));
  }

  Future<void> merge(String userId) =>
      _run(() => _guest.merge(userId), GuestLinkStatus.merged);

  Future<void> keepOnDevice() =>
      _run(_guest.keepOnDevice, GuestLinkStatus.kept);

  Future<void> _run(
    Future<void> Function() action,
    GuestLinkStatus done,
  ) async {
    if (state.status != GuestLinkStatus.ready) return;
    emit(
      GuestLinkState(status: GuestLinkStatus.working, summary: state.summary),
    );
    await action();
    if (isClosed) return;
    emit(GuestLinkState(status: done, summary: state.summary));
  }
}
