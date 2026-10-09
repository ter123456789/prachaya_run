part of 'record_bloc.dart';

sealed class RecordEvent {
  const RecordEvent();
}

final class RecordTypeChanged extends RecordEvent {
  const RecordTypeChanged(this.type);
  final ActivityType type;
}

final class RecordStarted extends RecordEvent {
  const RecordStarted();
}

final class RecordPaused extends RecordEvent {
  const RecordPaused();
}

final class RecordResumed extends RecordEvent {
  const RecordResumed();
}

final class RecordFinished extends RecordEvent {
  const RecordFinished();
}

/// Discards the current recording, or clears a saved one.
final class RecordReset extends RecordEvent {
  const RecordReset();
}

final class _LocationReceived extends RecordEvent {
  const _LocationReceived(this.point);
  final TrackPoint point;
}

final class _LocationFailed extends RecordEvent {
  const _LocationFailed();
}

final class _Ticked extends RecordEvent {
  const _Ticked();
}
