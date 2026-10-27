import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/health_import_store.dart';
import '../../../domain/services/health_source.dart';
import '../../../domain/usecases/import_activities.dart';

final class HealthImportState extends Equatable {
  const HealthImportState({
    this.available = false,
    this.enabled = false,
    this.access,
    this.importing = false,
    this.lastImportAt,
    this.lastImported = 0,
    this.newActivities = 0,
    this.failed = false,
  });

  /// False without a health store (tests, desktop) or when the device has
  /// none: the setting is hidden.
  final bool available;
  final bool enabled;
  final HealthAccess? access;
  final bool importing;
  final DateTime? lastImportAt;
  final int lastImported;

  /// New activities not yet acknowledged (the dashboard banner).
  final int newActivities;

  /// The last run failed, or turning it on was refused (shown next to the
  /// setting).
  final bool failed;

  HealthImportState copyWith({
    bool? available,
    bool? enabled,
    HealthAccess? access,
    bool? importing,
    DateTime? lastImportAt,
    int? lastImported,
    int? newActivities,
    bool? failed,
  }) => HealthImportState(
    available: available ?? this.available,
    enabled: enabled ?? this.enabled,
    access: access ?? this.access,
    importing: importing ?? this.importing,
    lastImportAt: lastImportAt ?? this.lastImportAt,
    lastImported: lastImported ?? this.lastImported,
    newActivities: newActivities ?? this.newActivities,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    available,
    enabled,
    access,
    importing,
    lastImportAt,
    lastImported,
    newActivities,
    failed,
  ];
}

/// Imports workouts from Apple Health / Health Connect when turned on: at
/// launch, whenever the app comes back to the foreground, and on demand.
class HealthImportCubit extends Cubit<HealthImportState> {
  HealthImportCubit({
    HealthSource? source,
    HealthImportStore? store,
    ImportActivities? importer,
    DateTime Function() clock = DateTime.now,
  }) : _source = source,
       _store = store,
       _importer = importer,
       _clock = clock,
       super(const HealthImportState());

  final HealthSource? _source;
  final HealthImportStore? _store;
  final ImportActivities? _importer;
  final DateTime Function() _clock;

  /// Bumped after a run that changed activities, so lists reload.
  final _changes = StreamController<ImportResult>.broadcast();
  Stream<ImportResult> get changes => _changes.stream;

  Future<void> load() async {
    final source = _source;
    final store = _store;
    if (source == null || store == null || _importer == null) return;
    final access = await source.availability();
    final settings = await store.load();
    if (isClosed) return;
    emit(
      state.copyWith(
        available: access != HealthAccess.unavailable,
        enabled: settings.enabled,
        access: access,
        lastImportAt: settings.lastImportAt,
        lastImported: settings.lastImported,
      ),
    );
    if (settings.enabled) await importNow();
  }

  /// Turns importing on from [daysBack] days ago (0 = only from now).
  Future<void> enable({required int daysBack}) async {
    final source = _source;
    final store = _store;
    if (source == null || store == null) return;
    final access = await source.requestAccess();
    if (isClosed) return;
    emit(
      state.copyWith(access: access, failed: access != HealthAccess.granted),
    );
    if (access != HealthAccess.granted) return;
    final now = _clock();
    final settings = await store.load();
    await store.save(
      settings.copyWith(
        enabled: true,
        since: now.subtract(Duration(days: daysBack)),
      ),
    );
    if (isClosed) return;
    emit(state.copyWith(enabled: true));
    await importNow();
  }

  Future<void> disable() async {
    final store = _store;
    if (store == null) return;
    final settings = await store.load();
    await store.save(settings.copyWith(enabled: false));
    if (!isClosed) emit(state.copyWith(enabled: false, newActivities: 0));
  }

  Future<void> importNow() async {
    final importer = _importer;
    if (importer == null || !state.enabled || state.importing) return;
    emit(state.copyWith(importing: true, failed: false));
    try {
      final result = await importer();
      if (isClosed) return;
      emit(
        state.copyWith(
          importing: false,
          lastImportAt: _clock(),
          lastImported: result.imported,
          newActivities: state.newActivities + result.imported,
        ),
      );
      if (result.changed) _changes.add(result);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(importing: false, failed: true));
    }
  }

  /// The banner was seen.
  void acknowledge() => emit(state.copyWith(newActivities: 0));

  @override
  Future<void> close() async {
    await _changes.close();
    return super.close();
  }
}
