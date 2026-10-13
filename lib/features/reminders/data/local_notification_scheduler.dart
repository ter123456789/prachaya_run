import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/reminder.dart';
import '../domain/repositories/reminder_scheduler.dart';

/// flutter_local_notifications. The payload is `<kind>|<target>`, so a
/// kind's pending reminders can be found and replaced after a restart.
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<ReminderTarget>.broadcast();
  final _actions = StreamController<String>.broadcast();

  /// Notification action buttons pressed (`actionId`), e.g. the recording
  /// notification's pause / lap.
  Stream<String> get actions => _actions.stream;

  /// The plugin, initialized, for other notifications on the same channel
  /// setup (the Android recording notification).
  Future<FlutterLocalNotificationsPlugin> plugin() async {
    await _init();
    return _plugin;
  }

  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'แจ้งเตือนการซ้อม',
    channelDescription: 'ก่อนซ้อมตามแผน เป้ารายสัปดาห์ และอากาศตอนเช้า',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: keep UTC; times are still absolute instants.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final action = r.actionId;
        if (action != null && action.isNotEmpty) {
          _actions.add(action);
          return;
        }
        final target = _target(r.payload);
        if (target != null) _taps.add(target);
      },
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  @override
  Future<void> replace(ReminderKind kind, List<Reminder> reminders) async {
    await _init();
    final wanted = {for (final r in reminders) r.id};
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (_kindOf(p.payload) == kind && !wanted.contains(p.id)) {
        await _plugin.cancel(id: p.id);
      }
    }
    final now = DateTime.now();
    for (final r in reminders) {
      if (!r.at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: _payload(r),
      );
    }
  }

  @override
  Future<void> showNow(Reminder r) async {
    await _init();
    await _plugin.show(
      id: r.id,
      title: r.title,
      body: r.body,
      notificationDetails: _details,
      payload: _payload(r),
    );
  }

  @override
  Stream<ReminderTarget> get taps {
    unawaited(_init());
    return _taps.stream;
  }

  @override
  Future<ReminderTarget?> launchTarget() async {
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return _target(details.notificationResponse?.payload);
  }

  static String _payload(Reminder r) =>
      '${r.kind.name}|${r.target?.encode() ?? ''}';

  static ReminderKind? _kindOf(String? payload) {
    final name = payload?.split('|').first;
    return ReminderKind.values.asNameMap()[name];
  }

  static ReminderTarget? _target(String? payload) {
    if (payload == null || !payload.contains('|')) return null;
    return ReminderTarget.decode(payload.substring(payload.indexOf('|') + 1));
  }
}
