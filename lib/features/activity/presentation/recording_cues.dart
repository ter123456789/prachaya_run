import '../../../core/units/distance_unit.dart';
import '../../../core/units/unit_labels.dart';
import '../../athlete/presentation/units.dart';
import '../domain/entities/activity_type.dart';
import '../domain/services/calories.dart';
import '../domain/services/recording_mirror.dart';
import '../domain/services/split_cues.dart';
import 'activity_labels.dart';
import 'bloc/record/record_bloc.dart';

/// `1 ชั่วโมง 5 นาที 12 วินาที`, for speech.
String spokenDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return [
    if (h > 0) '$h ชั่วโมง',
    if (m > 0) '$m นาที',
    if (s > 0 || (h == 0 && m == 0)) '$s วินาที',
  ].join(' ');
}

/// `2 กิโลเมตร. เวลารวม 10 นาที 30 วินาที. กิโลเมตรนี้ เพซ 5 นาที 12 วินาที`
String splitCueText(SplitCue cue, DistanceUnit unit, ActivityType type) {
  final name = unit.long;
  final pace = type.usesPace
      ? '$nameนี้ เพซ ${spokenDuration(cue.splitTime)}'
      : '$nameนี้ ความเร็ว ${unit.perHour(cue.splitSpeedMps).round()} '
            '$nameต่อชั่วโมง';
  return '${cue.index} $name. เวลารวม ${spokenDuration(cue.totalTime)}. $pace';
}

/// The Live Activity's view of [state].
LiveSnapshot liveSnapshot(RecordState state, UnitFormat units, double? kg) {
  final speed = state.averageSpeedMps;
  final pace = state.type.usesPace;
  return LiveSnapshot(
    title: 'กำลังบันทึก${state.type.label}',
    paused: state.status != RecordStatus.recording,
    elapsed: state.movingTime,
    distance: units.distance(state.distanceMeters),
    distanceUnit: units.unit.latin,
    paceLabel: pace ? 'เพซเฉลี่ย' : 'ความเร็วเฉลี่ย',
    pace: pace ? units.pace(speed) : units.speed(speed),
    paceUnit: pace ? units.unit.latinPace : units.unit.latinSpeed,
    lapNumber: state.lapNumber,
    lapDistance:
        '${units.distance(state.lapDistanceMeters)} ${units.distanceUnit}',
    calories: estimateCalories(
      type: state.type,
      distanceMeters: state.distanceMeters,
      movingTime: state.movingTime,
      weightKg: kg,
    ).round().toString(),
    elevation: '+${state.elevationGainMeters.round()}',
  );
}
