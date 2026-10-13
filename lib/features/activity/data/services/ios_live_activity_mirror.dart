import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/services/recording_mirror.dart';

/// iOS Live Activity (lock screen + Dynamic Island) through the
/// `prachaya/live_activity` channel (ios/Runner/LiveActivityBridge.swift,
/// UI in ios/RecordingWidget). Needs iOS 16.2; older systems ignore it.
class IosLiveActivityMirror implements RecordingMirror {
  IosLiveActivityMirror({
    MethodChannel channel = const MethodChannel('prachaya/live_activity'),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'command') return;
      final command = LiveCommand.values.asNameMap()[call.arguments];
      if (command != null) _commands.add(command);
    });
  }

  final MethodChannel _channel;
  final _commands = StreamController<LiveCommand>.broadcast();

  @override
  Stream<LiveCommand> get commands => _commands.stream;

  @override
  Future<void> show(LiveSnapshot s) => _call('show', {
    'title': s.title,
    'paused': s.paused,
    'elapsedSeconds': s.elapsed.inMilliseconds / 1000,
    'distance': s.distance,
    'distanceUnit': s.distanceUnit,
    'paceLabel': s.paceLabel,
    'pace': s.pace,
    'paceUnit': s.paceUnit,
    'lapNumber': s.lapNumber,
    'lapDistance': s.lapDistance,
    'calories': s.calories,
    'elevation': s.elevation,
  });

  @override
  Future<void> end() => _call('end');

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException {
      // Live Activities off or unsupported: recording works without them.
    } on MissingPluginException {
      // Not wired on this platform.
    }
  }
}
