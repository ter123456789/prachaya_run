import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/photo_share/domain/services/photo_source.dart';
import 'package:prachaya_run/features/photo_share/presentation/bloc/photo_overlay_cubit.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakePhotoSource photos;
  late FakeImageSink sink;
  final photo = Uint8List.fromList([1, 2, 3]);
  final png = Uint8List.fromList([9]);

  setUp(() {
    photos = FakePhotoSource();
    sink = FakeImageSink();
  });

  PhotoOverlayCubit build() => PhotoOverlayCubit(
    photoSource: photos,
    imageSink: sink,
    activity: sampleActivity(),
  );

  blocTest<PhotoOverlayCubit, PhotoOverlayState>(
    'picking a photo sets it; cancelling keeps the previous one',
    build: build,
    act: (cubit) async {
      photos.next = photo;
      await cubit.pickPhoto(PhotoOrigin.gallery);
      photos.next = null;
      await cubit.pickPhoto(PhotoOrigin.camera);
    },
    verify: (cubit) {
      expect(cubit.state.photo, same(photo));
      expect(cubit.state.status, PhotoOverlayStatus.editing);
    },
  );

  blocTest<PhotoOverlayCubit, PhotoOverlayState>(
    'save renders and stores the PNG',
    build: build,
    act: (cubit) => cubit.save(() async => png),
    expect: () => [
      const PhotoOverlayState(status: PhotoOverlayStatus.exporting),
      const PhotoOverlayState(status: PhotoOverlayStatus.saved),
    ],
    verify: (_) => expect(sink.saved.single, same(png)),
  );

  blocTest<PhotoOverlayCubit, PhotoOverlayState>(
    'save reports permission denied',
    setUp: () => sink.denySave = true,
    build: build,
    act: (cubit) => cubit.save(() async => png),
    skip: 1,
    expect: () => [
      const PhotoOverlayState(
        status: PhotoOverlayStatus.failure,
        failure: PhotoOverlayFailure.permissionDenied,
      ),
    ],
  );

  blocTest<PhotoOverlayCubit, PhotoOverlayState>(
    'render failure becomes exportFailed and nothing is shared',
    build: build,
    act: (cubit) => cubit.share(() async => throw StateError('boom')),
    skip: 1,
    expect: () => [
      const PhotoOverlayState(
        status: PhotoOverlayStatus.failure,
        failure: PhotoOverlayFailure.exportFailed,
      ),
    ],
    verify: (_) => expect(sink.shared, isEmpty),
  );

  group('stat selection', () {
    test('defaults to distance, average speed and time', () {
      expect(build().state.stats, [
        OverlayStat.distance,
        OverlayStat.avgSpeed,
        OverlayStat.time,
      ]);
    });

    test('adding keeps display order; never more than four', () {
      final cubit = build()
        ..toggleStat(OverlayStat.pace)
        ..toggleStat(OverlayStat.elevation); // fifth: rejected
      expect(cubit.state.stats, [
        OverlayStat.distance,
        OverlayStat.avgSpeed,
        OverlayStat.pace,
        OverlayStat.time,
      ]);
      expect(cubit.state.stats, isNot(contains(OverlayStat.elevation)));
    });

    test('cannot remove the last stat', () {
      final cubit = build()
        ..toggleStat(OverlayStat.distance)
        ..toggleStat(OverlayStat.avgSpeed)
        ..toggleStat(OverlayStat.time);
      expect(cubit.state.stats, [OverlayStat.time]);
    });
  });
}
