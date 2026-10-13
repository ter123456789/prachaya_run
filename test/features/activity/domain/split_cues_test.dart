import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/activity/domain/services/split_cues.dart';

void main() {
  test('each whole unit is announced once, with its own time', () {
    final cues = SplitCueTracker(1000);
    expect(cues.update(950, const Duration(minutes: 5)), isNull);
    final first = cues.update(1003, const Duration(minutes: 5, seconds: 12))!;
    expect(first.index, 1);
    expect(first.splitTime, const Duration(minutes: 5, seconds: 12));
    expect(cues.update(1500, const Duration(minutes: 8)), isNull);
    final second = cues.update(2001, const Duration(minutes: 10, seconds: 30))!;
    expect(second.index, 2);
    expect(second.splitTime, const Duration(minutes: 5, seconds: 18));
    expect(second.totalTime, const Duration(minutes: 10, seconds: 30));
    expect(second.splitSpeedMps, closeTo(1000 / 318, 1e-9));
  });

  test('a GPS jump over several units speaks only the latest', () {
    final cues = SplitCueTracker(1609.344);
    final cue = cues.update(3300, const Duration(minutes: 20))!;
    expect(cue.index, 2);
    expect(cue.splitTime, const Duration(minutes: 10));
    expect(cues.update(3301, const Duration(minutes: 20)), isNull);
  });
}
