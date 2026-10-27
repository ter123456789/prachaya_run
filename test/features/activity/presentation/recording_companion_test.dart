import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/services/recording_mirror.dart';
import 'package:prachaya_run/features/activity/domain/services/split_cues.dart';
import 'package:prachaya_run/features/activity/domain/services/voice_coach.dart';
import 'package:prachaya_run/features/activity/domain/usecases/save_activity.dart';
import 'package:prachaya_run/features/activity/presentation/bloc/record/record_bloc.dart';
import 'package:prachaya_run/features/activity/presentation/recording_cues.dart';
import 'package:prachaya_run/features/activity/presentation/widgets/recording_companion.dart';
import 'package:prachaya_run/features/athlete/presentation/bloc/units_cubit.dart';
import 'package:prachaya_run/features/athlete/presentation/units.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/profile_cubit.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder_settings.dart';
import 'package:prachaya_run/features/reminders/presentation/bloc/reminders_cubit.dart';

import '../../../helpers/fakes.dart';

class _Mirror implements RecordingMirror {
  final shown = <LiveSnapshot>[];
  int ended = 0;
  final _commands = StreamController<LiveCommand>.broadcast();

  void press(LiveCommand c) => _commands.add(c);

  @override
  Stream<LiveCommand> get commands => _commands.stream;

  @override
  Future<void> show(LiveSnapshot snapshot) async => shown.add(snapshot);

  @override
  Future<void> end() async => ended++;
}

class _Voice implements VoiceCoach {
  final said = <String>[];

  @override
  Future<void> speak(String text) async => said.add(text);
}

void main() {
  test('spoken texts', () {
    expect(
      spokenDuration(const Duration(minutes: 5, seconds: 12)),
      '5 นาที 12 วินาที',
    );
    expect(
      spokenDuration(const Duration(hours: 1, seconds: 3)),
      '1 ชั่วโมง 3 วินาที',
    );
    expect(spokenDuration(Duration.zero), '0 วินาที');
    const cue = SplitCue(
      index: 2,
      splitTime: Duration(minutes: 5, seconds: 12),
      totalTime: Duration(minutes: 10, seconds: 30),
      unitMeters: 1000,
    );
    expect(
      splitCueText(cue, DistanceUnit.km, ActivityType.run),
      '2 กิโลเมตร. เวลารวม 10 นาที 30 วินาที. กิโลเมตรนี้ เพซ 5 นาที 12 วินาที',
    );
    expect(
      splitCueText(cue, DistanceUnit.km, ActivityType.ride),
      endsWith('กิโลเมตรนี้ ความเร็ว 12 กิโลเมตรต่อชั่วโมง'),
    );
  });

  test('live snapshot texts follow the unit', () {
    final state = const RecordState(
      status: RecordStatus.recording,
      distanceMeters: 6800,
      movingTime: Duration(minutes: 34, seconds: 12),
      elevationGainMeters: 82,
      lapNumber: 4,
      lapStartMeters: 6000,
    );
    final km = liveSnapshot(state, const UnitFormat(DistanceUnit.km), 65);
    expect(km.title, 'กำลังบันทึกวิ่ง');
    expect(km.distance, '6.80');
    expect(km.distanceUnit, 'KM');
    expect(km.pace, '5:02');
    expect(km.paceUnit, '/KM');
    expect(km.lapDistance, '0.80 กม.');
    expect(km.calories, '458');
    expect(km.elevation, '+82');
    expect(km.paused, isFalse);
    final mi = liveSnapshot(state, const UnitFormat(DistanceUnit.mi), 65);
    expect(mi.distance, '4.23');
    expect(mi.paceUnit, '/MI');
  });

  late FakeLocationTracker tracker;
  late DateTime now;
  late _Mirror mirror;
  late _Voice voice;
  late RecordBloc bloc;
  late InMemoryReminderSettings settings;

  Future<void> pumpCompanion(
    WidgetTester tester, {
    bool audioCues = true,
  }) async {
    tracker = FakeLocationTracker();
    now = t0;
    mirror = _Mirror();
    voice = _Voice();
    settings = InMemoryReminderSettings()
      ..settings = ReminderSettings(audioCues: audioCues);
    bloc = RecordBloc(
      locationTracker: tracker,
      saveActivity: SaveActivity(InMemoryActivityRepository()),
      clock: () => now,
      tickInterval: const Duration(hours: 1),
    );
    final reminders = RemindersCubit(settings, FakeReminderScheduler())..load();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider(create: (_) => UnitsCubit(InMemorySettingsRepository())),
          BlocProvider(create: (_) => ProfileCubit(FakeProfileRepository())),
          BlocProvider.value(value: reminders),
        ],
        child: RecordingCompanion(
          mirror: mirror,
          voice: voice,
          minInterval: Duration.zero,
          child: const SizedBox(),
        ),
      ),
    );
  }

  late WidgetTester t;

  /// Stream cancels complete on the real microtask queue: let that run,
  /// then pump the fake one.
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> run(int fromPoint, int toPoint) async {
    for (var i = fromPoint; i <= toPoint; i++) {
      now = t0.add(Duration(seconds: 30 * i));
      tracker.emit(pointAt(i));
      await settle();
    }
  }

  testWidgets('mirrors the recording and speaks each km', (tester) async {
    t = tester;
    await pumpCompanion(tester);
    {
      bloc.add(const RecordStarted());
      await settle();
      await run(0, 10); // ~1.1 km
      expect(mirror.shown.last.distance, '1.11');
      expect(
        voice.said.single,
        '1 กิโลเมตร. เวลารวม 4 นาที 30 วินาที. กิโลเมตรนี้ เพซ 4 นาที 30 วินาที',
      );

      // Lock-screen buttons drive the recorder.
      mirror.press(LiveCommand.lap);
      await settle();
      expect(bloc.state.lapNumber, 2);
      expect(mirror.shown.last.lapNumber, 2);
      mirror.press(LiveCommand.pause);
      await settle();
      expect(bloc.state.status, RecordStatus.paused);
      expect(mirror.shown.last.paused, isTrue);
      mirror.press(LiveCommand.resume);
      await settle();
      expect(bloc.state.status, RecordStatus.recording);

      // Discarded: the Live Activity goes away.
      bloc.add(const RecordReset());
      await settle();
      expect(mirror.ended, 1);
    }
  });

  testWidgets('says when a vehicle pauses the recording', (tester) async {
    t = tester;
    await pumpCompanion(tester);
    {
      bloc.add(const RecordStarted());
      await settle();
      for (final fix in journey([(30, 3.5), (30, 15)])) {
        now = fix.timestamp;
        tracker.emit(fix);
        await settle();
      }
      expect(bloc.state.inVehicle, isTrue);
      expect(voice.said.single, vehicleCueText(true, ActivityType.run));
      expect(mirror.shown.last.paused, isTrue);
      expect(mirror.shown.last.title, 'อยู่บนยานพาหนะ · หยุดนับระยะ');

      mirror.press(LiveCommand.resume);
      await settle();
      expect(voice.said.last, 'กลับมาวิ่งแล้ว นับระยะต่อ');
      bloc.add(const RecordReset());
      await settle();
    }
  });

  testWidgets('voice cues off: silent', (tester) async {
    t = tester;
    await pumpCompanion(tester, audioCues: false);
    {
      await settle();
      bloc.add(const RecordStarted());
      await settle();
      await run(0, 10);
      expect(voice.said, isEmpty);
      expect(mirror.shown, isNotEmpty);
      bloc.add(const RecordReset());
      await settle();
    }
  });
}
