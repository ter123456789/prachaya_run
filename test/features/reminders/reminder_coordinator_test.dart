import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/core/storage/kv_store.dart';
import 'package:prachaya_run/core/units/distance_unit.dart';
import 'package:prachaya_run/features/activity/data/datasources/app_database.dart';
import 'package:prachaya_run/features/activity/domain/entities/weather_report.dart';
import 'package:prachaya_run/features/activity/domain/entities/weekly_stats.dart';
import 'package:prachaya_run/features/activity/domain/services/weather_service.dart';
import 'package:prachaya_run/features/athlete/presentation/units.dart';
import 'package:prachaya_run/features/reminders/data/kv_reminder_settings_repository.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder_settings.dart';
import 'package:prachaya_run/features/reminders/presentation/bloc/reminders_cubit.dart';
import 'package:prachaya_run/features/reminders/presentation/reminder_coordinator.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/fakes.dart';

class _Weather implements WeatherService {
  WeatherReport? next = const WeatherReport(
    temperatureC: 26.6,
    windKmh: 8,
    kind: WeatherKind.clear,
    isNight: false,
  );
  final asked = <DateTime>[];

  @override
  Future<WeatherReport?> forecast({
    required double lat,
    required double lng,
    required DateTime time,
  }) async {
    asked.add(time);
    return next;
  }

  @override
  Future<WeatherReport?> current({required double lat, required double lng}) =>
      throw UnimplementedError();

  @override
  Future<WeatherReport?> at({
    required double lat,
    required double lng,
    required DateTime time,
  }) => throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 10, 13, 12);
  const km = UnitFormat(DistanceUnit.km);
  late FakeReminderScheduler scheduler;
  late _Weather weather;
  late ReminderCoordinator coordinator;

  setUp(() {
    scheduler = FakeReminderScheduler();
    weather = _Weather();
    coordinator = ReminderCoordinator(
      scheduler,
      weather: weather,
      clock: () => now,
    );
  });

  final tempo = PlannedWorkout(
    id: 'w1',
    type: WorkoutType.tempo,
    title: 'Tempo Run',
    scheduledAt: DateTime(2026, 10, 14, 6),
    location: 'สวนลุมพินี',
    distanceMeters: 8000,
    paceMinSecPerKm: 310,
    paceMaxSecPerKm: 330,
  );

  test('a planned session gets a reminder with its real details', () async {
    await coordinator.planWorkouts([tempo], const ReminderSettings(), km);
    final r = scheduler.pending[ReminderKind.workout]!.single;
    expect(r.at, DateTime(2026, 10, 14, 5, 30));
    expect(r.title, 'อีก 30 นาที: Tempo Run');
    expect(
      r.body,
      '8 กม. • เพซ 5\'10"-5\'30" /กม. • สวนลุมพินี • เริ่ม 06:00 น.',
    );
    expect(r.target, ScheduleTarget(DateTime(2026, 10, 14)));
  });

  test('miles, a one-hour lead, and off', () async {
    await coordinator.planWorkouts(
      [tempo],
      const ReminderSettings(workoutLeadMinutes: 60),
      const UnitFormat(DistanceUnit.mi),
    );
    final r = scheduler.pending[ReminderKind.workout]!.single;
    expect(r.title, 'อีก 1 ชั่วโมง: Tempo Run');
    expect(r.body, startsWith('4.97 ไมล์ • เพซ 8\'19"-8\'51" /ไมล์'));

    await coordinator.planWorkouts(
      [tempo],
      const ReminderSettings(workoutLeadMinutes: null),
      km,
    );
    expect(scheduler.pending[ReminderKind.workout], isEmpty);
  });

  test('done or deleted sessions lose their reminder', () async {
    await coordinator.planWorkouts([tempo], const ReminderSettings(), km);
    await coordinator.planWorkouts(
      [tempo.copyWith(completedActivityId: () => 'a1')],
      const ReminderSettings(),
      km,
    );
    expect(scheduler.pending[ReminderKind.workout], isEmpty);
  });

  group('weekly goal', () {
    WeeklyStats week(double meters) => WeeklyStats(
      weekStart: DateTime(2026, 10, 12),
      distanceMeters: meters,
      movingTime: Duration.zero,
      elevationGainMeters: 0,
      activityCount: 4,
      previousWeekDistanceMeters: 0,
    );

    test('shown once, when the week crosses the goal', () async {
      await coordinator.weekChanged(
        week(18000),
        week(21500),
        const ReminderSettings(),
        km,
      );
      final r = scheduler.shown.single;
      expect(r.title, 'บรรลุเป้าหมายรายสัปดาห์!');
      expect(r.body, contains('20.00 กม.'));
      expect(r.body, contains('21.50 กม. จาก 4 ครั้ง'));

      await coordinator.weekChanged(
        week(21500),
        week(25000),
        const ReminderSettings(),
        km,
      );
      expect(scheduler.shown, hasLength(1));
    });

    test('not when turned off', () async {
      await coordinator.weekChanged(
        week(18000),
        week(21500),
        const ReminderSettings(weeklyGoal: false),
        km,
      );
      expect(scheduler.shown, isEmpty);
    });
  });

  group('morning weather', () {
    const on = ReminderSettings(morningWeather: true);
    const place = (lat: 13.73, lng: 100.54);

    test('tomorrow 06:00 from the forecast', () async {
      await coordinator.planWeather(place, on, km);
      expect(weather.asked.single, DateTime(2026, 10, 14, 6));
      final r = scheduler.pending[ReminderKind.weather]!.single;
      expect(r.at, DateTime(2026, 10, 14, 6));
      expect(r.title, 'อากาศสำหรับวิ่ง 06:00 น.');
      expect(r.body, '27°C แดดดี • ลม 8 กม./ชม. • อากาศดี เหมาะออกไปวิ่ง');
    });

    test('cancelled when off, without a place or without a forecast', () async {
      await coordinator.planWeather(place, on, km);
      await coordinator.planWeather(place, const ReminderSettings(), km);
      expect(scheduler.pending[ReminderKind.weather], isEmpty);

      await coordinator.planWeather(null, on, km);
      expect(scheduler.pending[ReminderKind.weather], isEmpty);

      weather.next = null;
      await coordinator.planWeather(place, on, km);
      expect(scheduler.pending[ReminderKind.weather], isEmpty);
    });
  });

  group('settings', () {
    late InMemoryReminderSettings repo;

    blocTest<RemindersCubit, RemindersState>(
      'turning a reminder on asks for permission; denied is shown',
      build: () {
        repo = InMemoryReminderSettings();
        scheduler.allow = false;
        return RemindersCubit(repo, scheduler);
      },
      act: (c) async {
        await c.load();
        await c.setMorningWeather(true);
      },
      skip: 2,
      expect: () => [
        const RemindersState(
          settings: ReminderSettings(morningWeather: true),
          loaded: true,
          permissionDenied: true,
        ),
      ],
      verify: (_) {
        expect(repo.settings.morningWeather, isTrue);
        expect(scheduler.permissionRequests, 1);
      },
    );

    blocTest<RemindersCubit, RemindersState>(
      'voice cues and turning off never ask',
      build: () => RemindersCubit(repo = InMemoryReminderSettings(), scheduler),
      act: (c) async {
        await c.load();
        await c.setAudioCues(false);
        await c.setWorkoutLead(null);
      },
      verify: (_) {
        expect(repo.settings.audioCues, isFalse);
        expect(repo.settings.workoutLeadMinutes, isNull);
        expect(scheduler.permissionRequests, 0);
      },
    );

    test('kept in the device settings row, next to the unit', () async {
      sqfliteFfiInit();
      final db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final kv = KvStore(db);
      await kv.write('settings', {'distanceUnit': 'mi'});
      final r = KvReminderSettingsRepository(kv);
      expect(await r.load(), const ReminderSettings());
      const changed = ReminderSettings(
        workoutLeadMinutes: null,
        weeklyGoal: false,
        morningWeather: true,
        audioCues: false,
      );
      await r.save(changed);
      expect(await r.load(), changed);
      expect((await kv.read('settings'))!['distanceUnit'], 'mi');
    });
  });
}
