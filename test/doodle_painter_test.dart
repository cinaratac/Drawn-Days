import 'dart:ui' as ui;

import 'package:drawn_days/models/doodle.dart';
import 'package:drawn_days/widgets/doodle_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a single dot matches the thickness of a round-capped line', () async {
    const width = 10.5;
    const color = 0xFF292621;
    const dot = Doodle(
      strokes: <DoodleStroke>[
        DoodleStroke(
          points: <ui.Offset>[ui.Offset(.5, .5)],
          colorValue: color,
          width: width,
        ),
      ],
    );
    const line = Doodle(
      strokes: <DoodleStroke>[
        DoodleStroke(
          points: <ui.Offset>[ui.Offset(.35, .5), ui.Offset(.65, .5)],
          colorValue: color,
          width: width,
        ),
      ],
    );

    final dotBounds = await _paintedBounds(dot);
    final lineBounds = await _paintedBounds(line);

    expect((dotBounds.height - lineBounds.height).abs(), lessThanOrEqualTo(1));
    expect((dotBounds.width - lineBounds.height).abs(), lessThanOrEqualTo(1));
  });
}

Future<({int width, int height})> _paintedBounds(Doodle doodle) async {
  const dimension = 360;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  DoodlePainter(doodle: doodle).paint(canvas, const ui.Size.square(360));
  final image = await recorder.endRecording().toImage(dimension, dimension);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (bytes == null) return (width: 0, height: 0);

  var minX = dimension;
  var minY = dimension;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < dimension; y++) {
    for (var x = 0; x < dimension; x++) {
      final alpha = bytes.getUint8(((y * dimension) + x) * 4 + 3);
      if (alpha <= 20) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return (
    width: maxX < minX ? 0 : maxX - minX + 1,
    height: maxY < minY ? 0 : maxY - minY + 1,
  );
}
