import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../reminders/data/local_notification_scheduler.dart';
import '../../domain/services/recording_mirror.dart';

/// Android: an ongoing notification while recording, with pause / lap
/// buttons (the Live Activity's counterpart).
class AndroidRecordingNotification implements RecordingMirror {
  AndroidRecordingNotification(this._notifications) {
    _notifications.actions.listen((id) {
      final command = LiveCommand.values.asNameMap()[id];
      if (command != null) _commands.add(command);
    });
  }

  static const _id = 7;
  final LocalNotificationScheduler _notifications;
  final _commands = StreamController<LiveCommand>.broadcast();

  @override
  Stream<LiveCommand> get commands => _commands.stream;

  @override
  Future<void> show(LiveSnapshot s) async {
    final plugin = await _notifications.plugin();
    final clock = s.elapsed;
    await plugin.show(
      id: _id,
      title: s.paused ? '${s.title} (หยุดชั่วคราว)' : s.title,
      body:
          '${s.distance} ${s.distanceUnit} • ${s.paceLabel} ${s.pace} ${s.paceUnit} '
          '• รอบที่ ${s.lapNumber}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'recording',
          'กำลังบันทึกกิจกรรม',
          channelDescription: 'ระยะ เวลา และเพซระหว่างบันทึก',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          usesChronometer: !s.paused,
          when: DateTime.now().subtract(clock).millisecondsSinceEpoch,
          actions: [
            AndroidNotificationAction(
              s.paused ? LiveCommand.resume.name : LiveCommand.pause.name,
              s.paused ? 'ทำต่อ' : 'หยุดชั่วคราว',
              showsUserInterface: true,
            ),
            if (!s.paused)
              AndroidNotificationAction(
                LiveCommand.lap.name,
                'เพิ่ม Lap',
                showsUserInterface: true,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> end() async {
    final plugin = await _notifications.plugin();
    await plugin.cancel(id: _id);
  }
}
