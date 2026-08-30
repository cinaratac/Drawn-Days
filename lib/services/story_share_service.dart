import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../utils/calendar_utils.dart';
import '../widgets/doodle_painter.dart';

enum StoryShareFormat { monthGrid, todaySquare, recentWeek }

class StoryShareService {
  StoryShareService._();

  static const _storyWidth = 1080;
  static const _storyHeight = 1920;
  static const _squareSize = 1080;
  static const _background = Color(0xFFF8F5EE);
  static const _border = Color(0xFFD9DED9);
  static const _label = Color(0xFF303631);

  static Future<Uint8List> renderMonthGrid({
    required DateTime month,
    required Map<String, Doodle> doodles,
  }) async {
    final logo = await _loadLogo();
    try {
      return await _renderGrid(
        columns: 4,
        rows: 8,
        dates: List<DateTime>.generate(
          daysInMonth(month),
          (index) => DateTime(month.year, month.month, index + 1),
        ),
        doodles: doodles,
        logo: logo,
        labelForDate: (date) => '${date.day}',
      );
    } finally {
      logo.dispose();
    }
  }

  static Future<Uint8List> renderTodaySquare({required Doodle doodle}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size.square(_squareSize.toDouble());
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    DoodlePainter(doodle: doodle).paint(canvas, size);
    return _encode(recorder, _squareSize, _squareSize);
  }

  static Future<Uint8List> renderRecentWeek({
    required DateTime today,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) async {
    final logo = await _loadLogo();
    try {
      final dates = List<DateTime>.generate(
        7,
        (index) => dateOnly(today).subtract(Duration(days: 6 - index)),
      );
      return await _renderGrid(
        columns: 2,
        rows: 4,
        dates: dates,
        doodles: doodles,
        logo: logo,
        labelForDate: (date) =>
            '${compactWeekdayName(date, language)}  ${date.day}',
      );
    } finally {
      logo.dispose();
    }
  }

  static Future<Uint8List> _renderGrid({
    required int columns,
    required int rows,
    required List<DateTime> dates,
    required Map<String, Doodle> doodles,
    required ui.Image logo,
    required String Function(DateTime date) labelForDate,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final storySize = Size(_storyWidth.toDouble(), _storyHeight.toDouble());
    canvas.drawRect(Offset.zero & storySize, Paint()..color = _background);

    final cellSize = _storyHeight / rows;
    final gridWidth = cellSize * columns;
    final left = (_storyWidth - gridWidth) / 2;
    final cellCount = columns * rows;

    for (var index = 0; index < cellCount; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final rect = Rect.fromLTWH(
        left + (column * cellSize),
        row * cellSize,
        cellSize,
        cellSize,
      );
      if (index < dates.length) {
        final date = dates[index];
        _drawDayCell(
          canvas,
          rect,
          doodle: doodles[dateKey(date)],
          label: labelForDate(date),
        );
      } else {
        _drawLogoCell(canvas, rect, logo);
      }
    }

    return _encode(recorder, _storyWidth, _storyHeight);
  }

  static void _drawDayCell(
    Canvas canvas,
    Rect rect, {
    required Doodle? doodle,
    required String label,
  }) {
    canvas.drawRect(rect, Paint()..color = Colors.white);
    final borderWidth = rect.width > 300 ? 3.0 : 2.0;
    canvas.drawRect(
      rect.deflate(borderWidth / 2),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    if (doodle != null) {
      canvas
        ..save()
        ..clipRect(rect.deflate(borderWidth))
        ..translate(rect.left, rect.top);
      DoodlePainter(doodle: doodle).paint(canvas, rect.size);
      canvas.restore();
    }

    final large = rect.width > 300;
    final padding = large ? 22.0 : 12.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: _label,
          fontSize: large ? 30 : 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - (padding * 2));
    final badgePaddingX = large ? 12.0 : 8.0;
    final badgePaddingY = large ? 7.0 : 4.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + padding - badgePaddingX,
        rect.top + padding - badgePaddingY,
        textPainter.width + (badgePaddingX * 2),
        textPainter.height + (badgePaddingY * 2),
      ),
      Radius.circular(large ? 10 : 7),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    textPainter.paint(canvas, Offset(rect.left + padding, rect.top + padding));
  }

  static void _drawLogoCell(Canvas canvas, Rect rect, ui.Image logo) {
    canvas.drawRect(rect, Paint()..color = Colors.white);
    final borderWidth = rect.width > 300 ? 3.0 : 2.0;
    canvas.drawRect(
      rect.deflate(borderWidth / 2),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
    final destination = rect.deflate(borderWidth);
    paintImage(
      canvas: canvas,
      rect: destination,
      image: logo,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  static Future<ui.Image> _loadLogo() async {
    final data = await rootBundle.load('lib/assets/app_icon.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static Future<Uint8List> _encode(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Share image could not be encoded');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
