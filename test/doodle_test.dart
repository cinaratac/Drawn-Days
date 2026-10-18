import 'package:drawn_days/models/doodle.dart';
import 'package:drawn_days/services/story_share_service.dart';
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

  test('doodles with unchanged strokes have the same content', () {
    const first = Doodle(
      strokes: [
        DoodleStroke(
          points: [Offset(0.1, 0.2), Offset(0.8, 0.7)],
          colorValue: 0xFFE56F4A,
          width: 6.5,
        ),
      ],
    );
    const second = Doodle(
      strokes: [
        DoodleStroke(
          points: [Offset(0.1, 0.2), Offset(0.8, 0.7)],
          colorValue: 0xFFE56F4A,
          width: 6.5,
        ),
      ],
    );
    const changed = Doodle(
      strokes: [
        DoodleStroke(
          points: [Offset(0.1, 0.2), Offset(0.8, 0.8)],
          colorValue: 0xFFE56F4A,
          width: 6.5,
        ),
      ],
    );

    expect(first.hasSameContent(second), isTrue);
    expect(first.hasSameContent(changed), isFalse);
    expect(const Doodle(strokes: []).hasSameContent(null), isTrue);
  });

  test('today share render uses updated stroke points', () async {
    final points = <Offset>[const Offset(0.1, 0.1), const Offset(0.2, 0.2)];
    final stroke = DoodleStroke(
      points: points,
      colorValue: 0xFF292621,
      width: 8,
    );
    final doodle = Doodle(strokes: [stroke]);

    final firstRender = await StoryShareService.renderTodaySquare(
      doodle: doodle,
    );
    points
      ..clear()
      ..addAll([const Offset(0.8, 0.1), const Offset(0.9, 0.9)]);

    final secondRender = await StoryShareService.renderTodaySquare(
      doodle: doodle,
    );

    expect(secondRender, isNot(firstRender));
  });
}
