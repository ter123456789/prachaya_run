/// The device's import settings and progress (kept in `kv`).
class HealthImportSettings {
  const HealthImportSettings({
    this.enabled = false,
    this.since,
    this.includeWalks = false,
    this.lastImportAt,
    this.lastImported = 0,
    this.seen = const {},
  });

  final bool enabled;

  /// Nothing that started before this is imported (chosen when turned on).
  final DateTime? since;

  /// Walks are imported as hikes only when asked: most are just strolls.
  final bool includeWalks;
  final DateTime? lastImportAt;

  /// How many the last run brought in.
  final int lastImported;

  /// Ids of workouts already handled (imported, merged, deleted by the
  /// user since…) with their start, so none comes back. Pruned by age.
  final Map<String, DateTime> seen;

  HealthImportSettings copyWith({
    bool? enabled,
    DateTime? since,
    bool? includeWalks,
    DateTime? lastImportAt,
    int? lastImported,
    Map<String, DateTime>? seen,
  }) => HealthImportSettings(
    enabled: enabled ?? this.enabled,
    since: since ?? this.since,
    includeWalks: includeWalks ?? this.includeWalks,
    lastImportAt: lastImportAt ?? this.lastImportAt,
    lastImported: lastImported ?? this.lastImported,
    seen: seen ?? this.seen,
  );
}

abstract interface class HealthImportStore {
  Future<HealthImportSettings> load();

  Future<void> save(HealthImportSettings settings);
}
