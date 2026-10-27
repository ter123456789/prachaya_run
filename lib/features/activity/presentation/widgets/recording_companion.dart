import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/units/distance_unit.dart';
import '../../../athlete/presentation/bloc/units_cubit.dart';
import '../../../athlete/presentation/units.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../reminders/presentation/bloc/reminders_cubit.dart';
import '../../domain/services/recording_mirror.dart';
import '../../domain/services/split_cues.dart';
import '../../domain/services/voice_coach.dart';
import '../bloc/record/record_bloc.dart';
import '../recording_cues.dart';

/// Follows the recording outside the record page: the Live Activity /
/// ongoing notification (and its pause / lap buttons) and spoken cues at
/// every whole km or mile.
class RecordingCompanion extends StatefulWidget {
  const RecordingCompanion({
    super.key,
    this.mirror,
    this.voice,
    this.minInterval = const Duration(seconds: 3),
    required this.child,
  });

  final RecordingMirror? mirror;
  final VoiceCoach? voice;

  /// Updates closer together than this are skipped unless the status or
  /// lap changed (ActivityKit has an update budget; the clock runs itself).
  final Duration minInterval;
  final Widget child;

  @override
  State<RecordingCompanion> createState() => _RecordingCompanionState();
}

class _RecordingCompanionState extends State<RecordingCompanion> {
  StreamSubscription<LiveCommand>? _commands;
  SplitCueTracker? _cues;
  LiveSnapshot? _shown;
  DateTime? _shownAt;
  bool _live = false;
  bool _inVehicle = false;

  @override
  void initState() {
    super.initState();
    _commands = widget.mirror?.commands.listen((command) {
      if (!mounted) return;
      context.read<RecordBloc>().add(switch (command) {
        LiveCommand.pause => const RecordPaused(),
        LiveCommand.resume => const RecordResumed(),
        LiveCommand.lap => const RecordLapped(),
      });
    });
  }

  @override
  void dispose() {
    _commands?.cancel();
    super.dispose();
  }

  void _onRecord(BuildContext context, RecordState state) {
    if (!state.isActive) {
      _cues = null;
      _inVehicle = false;
      if (_live) {
        _live = false;
        _shown = null;
        unawaited(widget.mirror?.end());
      }
      return;
    }
    final units = UnitFormat(context.read<UnitsCubit>().state);
    _speak(context, state, units);
    _mirror(context, state, units);
  }

  void _speak(BuildContext context, RecordState state, UnitFormat units) {
    final voice = widget.voice;
    if (voice == null) return;
    final tracker = _cues ??= SplitCueTracker(units.unit.meters);
    final cue = tracker.update(state.distanceMeters, state.movingTime);
    final on = context.read<RemindersCubit>().state.settings.audioCues;
    final vehicleChanged = state.inVehicle != _inVehicle;
    _inVehicle = state.inVehicle;
    if (!on) return;
    if (vehicleChanged) {
      unawaited(voice.speak(vehicleCueText(state.inVehicle, state.type)));
    } else if (cue != null) {
      unawaited(voice.speak(splitCueText(cue, units.unit, state.type)));
    }
  }

  void _mirror(BuildContext context, RecordState state, UnitFormat units) {
    final mirror = widget.mirror;
    if (mirror == null) return;
    final kg = context.read<ProfileCubit>().state.profile.weightKg;
    final next = liveSnapshot(state, units, kg);
    final last = _shown;
    final now = DateTime.now();
    final urgent =
        last == null ||
        last.paused != next.paused ||
        last.lapNumber != next.lapNumber;
    final due =
        _shownAt == null || now.difference(_shownAt!) >= widget.minInterval;
    if (!urgent && (!due || last == next)) return;
    _shown = next;
    _shownAt = now;
    _live = true;
    unawaited(mirror.show(next));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listener: _onRecord,
      child: widget.child,
    );
  }
}
