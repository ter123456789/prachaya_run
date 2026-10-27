import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/geo_point.dart';
import 'package:prachaya_run/features/route_builder/domain/entities/planned_route.dart';
import 'package:prachaya_run/features/route_builder/domain/repositories/route_snapper.dart';
import 'package:prachaya_run/features/route_builder/domain/usecases/snap_drawing.dart';
import 'package:prachaya_run/features/route_builder/presentation/bloc/route_draw_cubit.dart';

import '../../../helpers/fakes.dart';

GeoPoint at(double north, double east) =>
    GeoPoint(13.73 + north / 111195, 100.54 + east / 108040);

/// Answers only when [answer] completes.
class SlowSnapper implements RouteSnapper {
  final answer = Completer<SnappedPath>();

  @override
  Future<SnappedPath> snap(List<GeoPoint> shape) => answer.future;
}

void main() {
  late FakeRouteSnapper snapper;
  late InMemoryRouteRepository repo;
  late RouteDrawCubit cubit;

  setUp(() {
    snapper = FakeRouteSnapper();
    repo = InMemoryRouteRepository();
    cubit = RouteDrawCubit(SnapDrawing(snapper), repo);
  });
  tearDown(() => cubit.close());

  void drawSquare() {
    cubit
      ..startStroke(at(0, 0))
      ..extendStroke(at(0, 400))
      ..extendStroke(at(400, 400))
      ..extendStroke(at(400, 0))
      ..endStroke();
  }

  test('draw, snap and save a closed route', () async {
    drawSquare();
    expect(cubit.state.hasDrawing, isTrue);
    expect(cubit.state.drawnMeters, closeTo(1600, 2)); // closed back to start

    await cubit.snap();
    expect(cubit.state.status, SnapStatus.snapped);
    expect(cubit.state.plan!.fit!.score, 100);

    final saved = await cubit.save('สี่เหลี่ยม');
    final stored = repo.store[saved.id]!;
    expect(stored.name, 'สี่เหลี่ยม');
    expect(stored.closed, isTrue);
    expect(stored.score, 100);
    expect(stored.route, isNotNull);
    expect(stored.distanceMeters, closeTo(1600, 2));
  });

  test('a tap leaves no stroke; undo and clear', () {
    cubit
      ..startStroke(at(0, 0))
      ..endStroke();
    expect(cubit.state.strokes, isEmpty);

    drawSquare();
    cubit
      ..startStroke(at(500, 0))
      ..extendStroke(at(600, 0))
      ..endStroke();
    expect(cubit.state.strokes, hasLength(2));
    cubit.undo();
    expect(cubit.state.strokes, hasLength(1));
    cubit.clear();
    expect(cubit.state.hasDrawing, isFalse);
  });

  test('changing the drawing or the loop drops the snapped plan', () async {
    drawSquare();
    await cubit.snap();
    cubit.setClosed(false);
    expect(cubit.state.plan, isNull);
    expect(cubit.state.status, SnapStatus.idle);

    await cubit.snap();
    cubit.undo();
    expect(cubit.state.plan, isNull);
  });

  test('signed out: snapping fails, the drawing alone can be saved', () async {
    snapper.error = RouteSnapError.signedOut;
    drawSquare();
    await cubit.snap();
    expect(cubit.state.status, SnapStatus.failed);
    expect(cubit.state.error, RouteSnapError.signedOut);

    final saved = await cubit.save('ร่าง');
    expect(repo.store[saved.id]!.isSnapped, isFalse);
    expect(repo.store[saved.id]!.score, isNull);
    expect(repo.store[saved.id]!.distanceMeters, closeTo(1600, 2));
  });

  test('an answer for an older drawing is ignored', () async {
    final slow = SlowSnapper();
    final c = RouteDrawCubit(SnapDrawing(slow), repo);
    addTearDown(c.close);
    c
      ..startStroke(at(0, 0))
      ..extendStroke(at(0, 400))
      ..endStroke();
    final pending = c.snap();
    expect(c.state.status, SnapStatus.snapping);
    c
      ..startStroke(at(400, 0))
      ..extendStroke(at(400, 400))
      ..endStroke();
    slow.answer.complete(SnappedPath([at(0, 0), at(0, 400)], 400));
    await pending;
    expect(c.state.plan, isNull);
    expect(c.state.status, SnapStatus.idle);
  });

  test('editing a saved route reopens its drawing and result', () async {
    drawSquare();
    await cubit.snap();
    final saved = await cubit.save('สี่เหลี่ยม');

    final edit = RouteDrawCubit(
      SnapDrawing(snapper),
      repo,
      editing: repo.store[saved.id],
    );
    addTearDown(edit.close);
    expect(edit.state.tool, DrawTool.pan);
    expect(edit.state.status, SnapStatus.snapped);
    expect(edit.state.plan!.fit!.score, 100);
    // The repeated start of a closed drawing is not a stroke point.
    expect(
      edit.state.strokes.single.last,
      isNot(edit.state.strokes.single.first),
    );

    final again = await edit.save('สี่เหลี่ยม 2');
    expect(again.id, saved.id);
    expect(repo.store, hasLength(1));
    expect(repo.store[saved.id]!.name, 'สี่เหลี่ยม 2');
  });

  test('saving with an empty name is refused', () {
    drawSquare();
    expect(() => cubit.save(' '), throwsA(isA<RouteValidationException>()));
  });
}
