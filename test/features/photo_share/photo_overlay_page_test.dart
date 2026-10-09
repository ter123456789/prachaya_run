import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/photo_share/domain/services/image_sink.dart';
import 'package:prachaya_run/features/photo_share/domain/services/photo_source.dart';
import 'package:prachaya_run/features/photo_share/presentation/pages/photo_overlay_page.dart';
import 'package:prachaya_run/features/photo_share/presentation/widgets/activity_overlay.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeImageSink sink;
  late FakePhotoSource photos;

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    sink = FakeImageSink();
    photos = FakePhotoSource();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<PhotoSource>.value(value: photos),
          RepositoryProvider<ImageSink>.value(value: sink),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(PhotoOverlayPage.route(sampleActivity())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    // The chip row is below the preview, so it is the last match.
    final chip = find.text(label).last;
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<Uint8List> exportPng(WidgetTester tester) async {
    await tester.tap(find.text('แชร์'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    return sink.shared.last;
  }

  /// Width and the alpha of the top-left pixel.
  Future<(int, int)> inspect(WidgetTester tester, Uint8List png) async {
    return (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (image.width, rgba!.getUint8(3));
    }))!;
  }

  testWidgets('default export: card background with distance, speed, time', (
    tester,
  ) async {
    await openEditor(tester);

    // Activity title appears only on the card background header.
    expect(find.text('วิ่งตอนเช้า'), findsOneWidget);
    expect(find.text('28:30'), findsOneWidget);
    expect(find.textContaining('กม./ชม.'), findsOneWidget);

    final (width, cornerAlpha) = await inspect(tester, await exportPng(tester));
    expect(width, 1080);
    expect(cornerAlpha, 255, reason: 'card background must be opaque');
  });

  testWidgets('transparent background exports a see-through PNG', (
    tester,
  ) async {
    await openEditor(tester);
    await tapChip(tester, 'พื้นใส');
    expect(find.text('วิ่งตอนเช้า'), findsNothing);

    final (_, cornerAlpha) = await inspect(tester, await exportPng(tester));
    expect(cornerAlpha, 0);
  });

  testWidgets('transparent with a photo cuts the photo out too', (
    tester,
  ) async {
    await openEditor(tester);
    photos.next = _onePixelPng;
    await tester.tap(find.text('เลือกรูป').last);
    await tester.pumpAndSettle();
    expect(find.text('ลบรูป'), findsOneWidget);

    await tapChip(tester, 'พื้นใส');
    expect(find.byType(Image), findsNothing);

    final (_, cornerAlpha) = await inspect(tester, await exportPng(tester));
    expect(cornerAlpha, 0);
  });

  testWidgets('transparent glass layout drops the frosted tiles', (
    tester,
  ) async {
    await openEditor(tester);
    await tapChip(tester, 'พื้นใส');
    await tapChip(tester, 'กระจก');
    expect(
      find.descendant(
        of: find.byType(ActivityOverlay),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('stat chips toggle what is drawn', (tester) async {
    await openEditor(tester);
    expect(find.textContaining('/กม.'), findsNothing);

    await tapChip(tester, 'เพซ');
    expect(find.textContaining('/กม.'), findsOneWidget);

    await tapChip(tester, 'เวลา');
    expect(find.text('28:30'), findsNothing);
  });

  testWidgets('classic layout in English, Strava style', (tester) async {
    await openEditor(tester);
    await tapChip(tester, 'EN');

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Avg Speed'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('28m 30s'), findsOneWidget);
    expect(find.text('PRACHAYA RUN'), findsOneWidget);
  });
}

/// Opaque red 1×1 PNG.
final _onePixelPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
  ),
);
