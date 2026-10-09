part of 'record_bloc.dart';

enum RecordStatus { idle, recording, paused, saving, saved }

enum RecordFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  locationLost,
  tooShort,
  saveFailed;

  static RecordFailure fromAccess(LocationAccess access) => switch (access) {
    LocationAccess.serviceDisabled => serviceDisabled,
    LocationAccess.deniedForever => permissionDeniedForever,
    LocationAccess.denied || LocationAccess.granted => permissionDenied,
  };
}

final class RecordState extends Equatable {
  const RecordState({
    this.type = ActivityType.run,
    this.status = RecordStatus.idle,
    this.segments = const [],
    this.revision = 0,
    this.distanceMeters = 0,
    this.elevationGainMeters = 0,
    this.movingTime = Duration.zero,
    this.failure,
    this.savedActivityId,
  });

  final ActivityType type;
  final RecordStatus status;

  /// Live view of the session track. It grows in place, so equality uses
  /// [revision] instead of comparing every point.
  final List<List<TrackPoint>> segments;
  final int revision;

  final double distanceMeters;
  final double elevationGainMeters;
  final Duration movingTime;

  /// One-shot error; [copyWith] clears it unless passed again.
  final RecordFailure? failure;
  final String? savedActivityId;

  bool get isActive =>
      status == RecordStatus.recording || status == RecordStatus.paused;

  double get averageSpeedMps {
    final seconds = movingTime.inMilliseconds / 1000;
    return seconds <= 0 ? 0 : distanceMeters / seconds;
  }

  RecordState copyWith({
    ActivityType? type,
    RecordStatus? status,
    List<List<TrackPoint>>? segments,
    int? revision,
    double? distanceMeters,
    double? elevationGainMeters,
    Duration? movingTime,
    RecordFailure? failure,
    String? savedActivityId,
  }) => RecordState(
    type: type ?? this.type,
    status: status ?? this.status,
    segments: segments ?? this.segments,
    revision: revision ?? this.revision,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
    movingTime: movingTime ?? this.movingTime,
    failure: failure,
    savedActivityId: savedActivityId ?? this.savedActivityId,
  );

  @override
  List<Object?> get props => [
    type,
    status,
    revision,
    distanceMeters,
    elevationGainMeters,
    movingTime,
    failure,
    savedActivityId,
  ];
}
