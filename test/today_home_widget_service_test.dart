import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drawn_days/models/app_settings.dart';
import 'package:drawn_days/models/doodle.dart';
import 'package:drawn_days/services/today_home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sample = Doodle(
    strokes: [
      DoodleStroke(
        points: [ui.Offset(.18, .25), ui.Offset(.5, .72), ui.Offset(.82, .3)],
        colorValue: 0xFF2E6B50,
        width: 7,
      ),
    ],
  );

  testWidgets('renders medium last-seven-days widget artwork', (tester) async {
    final bytes = await tester.runAsync(
      () => TodayHomeWidgetService.renderWeekArtwork(
        date: DateTime(2026, 10, 19),
        doodles: const {'2026-10-19': sample},
        language: AppLanguage.english,
      ),
    );
    expect(bytes, isNotNull);
    final image = await tester.runAsync(() => _decode(bytes!));
    expect(image, isNotNull);
    final rendered = image!;
    expect(rendered.width, 1024);
    expect(rendered.height, 512);
    rendered.dispose();
  });

  testWidgets('renders large month widget artwork', (tester) async {
    final bytes = await tester.runAsync(
      () => TodayHomeWidgetService.renderMonthArtwork(
        date: DateTime(2026, 10, 19),
        doodles: const {'2026-10-19': sample},
        language: AppLanguage.english,
      ),
    );
    expect(bytes, isNotNull);
    final image = await tester.runAsync(() => _decode(bytes!));
    expect(image, isNotNull);
    final rendered = image!;
    expect(rendered.width, 1024);
    expect(rendered.height, 1024);
    rendered.dispose();
  });
}

Future<ui.Image> _decode(List<int> bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    Uint8List.fromList(bytes),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}
