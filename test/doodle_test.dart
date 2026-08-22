import 'package:drawn_days/models/doodle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doodle survives a JSON round trip', () {
    const doodle = Doodle(
      strokes: [
        DoodleStroke(
          points: [Offset(0.1, 0.2), Offset(0.8, 0.7)],
          colorValue: 0xFFE56F4A,
          width: 6.5,
        ),
      ],
    );

    final restored = Doodle.fromJson(doodle.toJson());

    expect(restored.strokes, hasLength(1));
    expect(restored.strokes.single.points, const [
      Offset(0.1, 0.2),
      Offset(0.8, 0.7),
    ]);
    expect(restored.strokes.single.colorValue, 0xFFE56F4A);
    expect(restored.strokes.single.width, 6.5);
  });
}
