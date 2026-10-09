import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/entities/activity_type.dart';
import 'package:prachaya_run/features/activity/domain/entities/recording_session.dart';
import 'package:prachaya_run/features/activity/domain/usecases/save_activity.dart';

import '../../../helpers/fakes.dart';

void main() {
  late InMemoryActivityRepository repository;
  late SaveActivity saveActivity;

  setUp(() {
    repository = InMemoryActivityRepository();
    saveActivity = SaveActivity(repository);
  });

  test('rejects sessions shorter than the minimum distance', () {
    final session = RecordingSession(type: ActivityType.run, startedAt: t0)
      ..addPoint(pointAt(0));
    expect(
      () => saveActivity(session, title: 't', endedAt: t0),
      throwsA(isA<ActivityTooShortException>()),
    );
    expect(repository.store, isEmpty);
  });

  test('persists a valid session', () async {
    final session = RecordingSession(type: ActivityType.hike, startedAt: t0)
      ..addPoint(pointAt(0))
      ..addPoint(pointAt(1));
    final saved = await saveActivity(session, title: 'hike', endedAt: t0);
    expect(repository.store[saved.id]?.title, 'hike');
  });
}
