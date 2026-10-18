import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:drawn_days/models/doodle.dart';
import 'package:drawn_days/utils/doodle_eraser.dart';

void main() {
  test('eraser removes only the touched portion of a stroke', () {
    final stroke = DoodleStroke(
      points: List<Offset>.generate(11, (index) => Offset(index / 10, .5)),
      colorValue: 0xFF292621,
      width: 6.5,
    );

    final result = eraseDoodleAlong(
      <DoodleStroke>[stroke],
      from: const Offset(.5, .4),
      to: const Offset(.5, .6),
      canvasSize: const Size(100, 100),
      eraserWidth: 10,
    );

    expect(result, hasLength(2));
    expect(result.first.points.last.dx, lessThan(.5));
    expect(result.last.points.first.dx, greaterThan(.5));
    expect(
      result.expand((part) => part.points),
      isNot(contains(const Offset(.5, .5))),
    );
  });

  test('eraser leaves untouched strokes unchanged', () {
    final stroke = DoodleStroke(
      points: const <Offset>[Offset(.1, .1), Offset(.2, .2)],
      colorValue: 0xFF292621,
      width: 3.5,
    );

    final result = eraseDoodleAlong(
      <DoodleStroke>[stroke],
      from: const Offset(.8, .9),
      to: const Offset(.9, .9),
      canvasSize: const Size(100, 100),
      eraserWidth: 6.5,
    );

    expect(
      Doodle(
        strokes: result,
      ).hasSameContent(Doodle(strokes: <DoodleStroke>[stroke])),
      isTrue,
    );
  });

  test('eraser sweeps continuously between pointer samples', () {
    final stroke = DoodleStroke(
      points: const <Offset>[
        Offset(.1, .5),
        Offset(.3, .5),
        Offset(.5, .5),
        Offset(.7, .5),
        Offset(.9, .5),
      ],
      colorValue: 0xFF292621,
      width: 3.5,
    );

    final result = eraseDoodleAlong(
      <DoodleStroke>[stroke],
      from: const Offset(.2, .5),
      to: const Offset(.8, .5),
      canvasSize: const Size(360, 180),
      eraserWidth: 3.5,
    );

    expect(result, hasLength(2));
    expect(result.first.points.first, const Offset(.1, .5));
    expect(result.last.points.last, const Offset(.9, .5));
    expect(
      result.expand((part) => part.points),
      isNot(contains(const Offset(.5, .5))),
    );
  });

  test('selected width changes the eraser hit area', () {
    final dot = DoodleStroke(
      points: const <Offset>[Offset(.5, .5)],
      colorValue: 0xFF292621,
      width: 3.5,
    );
    const nearDot = Offset(.5, .518);

    final thin = eraseDoodleAlong(
      <DoodleStroke>[dot],
      from: nearDot,
      to: nearDot,
      canvasSize: const Size(360, 360),
      eraserWidth: 3.5,
    );
    final thick = eraseDoodleAlong(
      <DoodleStroke>[dot],
      from: nearDot,
      to: nearDot,
      canvasSize: const Size(360, 360),
      eraserWidth: 10.5,
    );

    expect(thin, hasLength(1));
    expect(thick, isEmpty);
  });
}
