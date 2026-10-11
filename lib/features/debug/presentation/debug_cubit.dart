import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/entities/gps_simulation.dart';
import '../domain/services/debug_tools.dart';

final class DebugState extends Equatable {
  const DebugState({
    required this.gps,
    required this.offline,
    this.pending,
    this.busy = false,
    this.message,
  });

  final GpsSimulation gps;
  final bool offline;
  final int? pending;
  final bool busy;

  /// One-shot feedback for a snackbar.
  final String? message;

  DebugState copyWith({
    GpsSimulation? gps,
    bool? offline,
    int? pending,
    bool? busy,
    String? message,
  }) => DebugState(
    gps: gps ?? this.gps,
    offline: offline ?? this.offline,
    pending: pending ?? this.pending,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [gps, offline, pending, busy, message];
}

class DebugCubit extends Cubit<DebugState> {
  DebugCubit(this._tools)
    : super(DebugState(gps: _tools.gps, offline: _tools.offline));

  final DebugTools _tools;

  void setGps(GpsSimulation gps) {
    _tools.setGps(gps);
    emit(state.copyWith(gps: gps));
  }

  void dropGpsSignal() {
    _tools.dropGpsSignal();
    emit(state.copyWith(message: 'ตัดสัญญาณ GPS แล้ว'));
  }

  void setOffline(bool offline) {
    _tools.setOffline(offline);
    emit(state.copyWith(offline: offline));
  }

  void expireToken() {
    _tools.expireAccessTokenOnce();
    emit(
      state.copyWith(
        message: 'request ถัดไปจะได้ token_expired → แอปต้อง refresh เอง',
      ),
    );
  }

  Future<void> breakSession() async {
    await _tools.breakSession();
    emit(
      state.copyWith(
        message: 'refresh token เสียแล้ว ซิงก์ครั้งถัดไปจะโดน logout',
      ),
    );
  }

  Future<void> refreshPending() async =>
      emit(state.copyWith(pending: await _tools.pendingSyncCount()));

  Future<void> seed() => _run(() async {
    final n = await _tools.seedActivities();
    return 'เพิ่มกิจกรรมตัวอย่าง $n รายการ';
  });

  Future<void> clearLocal() => _run(() async {
    await _tools.clearLocalData();
    return 'ล้างข้อมูลในเครื่องแล้ว';
  });

  Future<void> _run(Future<String> Function() action) async {
    emit(state.copyWith(busy: true));
    final message = await action();
    emit(
      state.copyWith(
        busy: false,
        pending: await _tools.pendingSyncCount(),
        message: message,
      ),
    );
  }
}
