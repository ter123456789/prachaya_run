import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/reminders/domain/entities/reminder.dart';
import 'package:prachaya_run/features/training/domain/entities/planned_workout.dart';
import 'package:prachaya_run/features/training/presentation/pages/schedule_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final morning = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6);
  final tempo = PlannedWorkout(
    id: 'w1',
    type: WorkoutType.tempo,
    title: 'Tempo Run',
    scheduledAt: morning,
    distanceMeters: 8000,
    paceMinSecPerKm: 310,
    paceMaxSecPerKm: 330,
  );

  testWidgets('plans become reminders on launch; permission asked once', (
    tester,
  ) async {
    final app = TestApp()..workouts.store[tempo.id] = tempo;
    await app.pump(tester);
    final r = app.reminders.pending[ReminderKind.workout]!.single;
    expect(r.title, 'อีก 30 นาที: Tempo Run');
    expect(r.at, morning.subtract(const Duration(minutes: 30)));
    expect(app.reminders.permissionRequests, 1);
  });

  testWidgets('tapping a reminder opens the schedule on its day', (
    tester,
  ) async {
    final app = TestApp()..workouts.store[tempo.id] = tempo;
    await app.pump(tester);
    app.reminders.tap(ScheduleTarget(morning));
    await tester.pumpAndSettle();
    expect(find.byType(SchedulePage), findsOneWidget);
    // The focus card shows that day's session.
    expect(find.text('Tempo Run'), findsWidgets);
  });

  testWidgets('a reminder that launched the app opens the schedule', (
    tester,
  ) async {
    final app = TestApp()..workouts.store[tempo.id] = tempo;
    app.reminders.launch = ScheduleTarget(morning);
    await app.pump(tester);
    expect(find.byType(SchedulePage), findsOneWidget);
  });
}
