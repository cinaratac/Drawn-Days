import 'dart:math' as math;
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
  static const _page = Color(0xFFF7F3E8);
  static const _paper = Color(0xFFFFFEF8);
  static const _ink = Color(0xFF173F32);
  static const _mutedInk = Color(0xFF66706A);
  static const _grid = Color(0xFF9BA49E);
  static const _rust = Color(0xFFB5653F);
  static const _yellow = Color(0xFFF2D974);
  static const _blueTape = Color(0xFFB8D5E7);
  static const _greenTape = Color(0xFFB9DCC7);
  static const _pinkTape = Color(0xFFEBC1AE);

  static Future<Uint8List> renderMonthGrid({
    required DateTime month,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) async {
    final logo = await _loadLogo();
    try {
      return await _renderStoryGrid(
        columns: 4,
        rows: 8,
        dates: List<DateTime>.generate(
          daysInMonth(month),
          (index) => DateTime(month.year, month.month, index + 1),
        ),
        doodles: doodles,
        logo: logo,
        title: monthTitle(month, language),
        labelForDate: (date) => '${date.day}',
        seed: month.year * 100 + month.month,
      );
    } finally {
      logo.dispose();
    }
  }

  static Future<Uint8List> renderTodaySquare({
    required DateTime date,
    required Doodle doodle,
    required AppLanguage language,
  }) async {
    final logo = await _loadLogo();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size.square(1080);
    _drawBackground(
      canvas,
      size,
      date.year * 10000 + date.month * 100 + date.day,
    );
    _drawSpiral(canvas, size.width, top: 34, spacing: 62, scale: .82);
    _drawBrand(canvas, logo, const Offset(58, 92), compact: true);

    final card = const Rect.fromLTWH(62, 205, 956, 805);
    _drawLargeTodayCard(
      canvas,
      card,
      date: date,
      doodle: doodle,
      language: language,
      seed: date.day + date.month * 31,
    );

    return _encode(recorder, _squareSize, _squareSize);
  }

  static Future<Uint8List> renderDoodleSquare({required Doodle doodle}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size.square(1080);
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    DoodlePainter(doodle: doodle, cacheGeometry: false).paint(canvas, size);
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
      final first = dates.first;
      final range =
          '${first.day} ${monthNames(language)[first.month - 1]}  —  '
          '${today.day} ${monthNames(language)[today.month - 1]}';
      return await _renderStoryGrid(
        columns: 2,
        rows: 4,
        dates: dates,
        doodles: doodles,
        logo: logo,
        title: range,
        labelForDate: (date) =>
            '${date.day}  ${compactWeekdayName(date, language)}',
        seed: today.year * 10000 + today.month * 100 + today.day,
      );
    } finally {
      logo.dispose();
    }
  }

  static Future<Uint8List> _renderStoryGrid({
    required int columns,
    required int rows,
    required List<DateTime> dates,
    required Map<String, Doodle> doodles,
    required ui.Image logo,
    required String title,
    String? subtitle,
    required String Function(DateTime date) labelForDate,
    required int seed,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const storySize = Size(1080, 1920);
    _drawBackground(canvas, storySize, seed);
    _drawSpiral(canvas, storySize.width, top: 34, spacing: 62, scale: .82);
    _drawBrand(canvas, logo, const Offset(58, 92));
    _paintText(
      canvas,
      title,
      const Offset(58, 205),
      fontSize: 79,
      color: _ink,
      maxWidth: 920,
      weight: FontWeight.w600,
    );
    _drawWobblyUnderline(
      canvas,
      const Offset(61, 296),
      math.min(730, 45.0 + title.length * 39),
      _rust,
      seed: seed,
      strokeWidth: 5,
    );
    if (subtitle != null) {
      _paintText(
        canvas,
        subtitle,
        const Offset(62, 315),
        fontSize: 34,
        color: _mutedInk,
        maxWidth: 900,
      );
    }

    const gridLeft = 52.0;
    const gridRight = 52.0;
    final gridTop = subtitle == null ? 335.0 : 382.0;
    const gridBottom = 1850.0;
    final horizontalGap = columns == 4 ? 13.0 : 22.0;
    final verticalGap = columns == 4 ? 10.0 : 18.0;
    final cellWidth =
        (_storyWidth - gridLeft - gridRight - horizontalGap * (columns - 1)) /
        columns;
    final cellHeight = (gridBottom - gridTop - verticalGap * (rows - 1)) / rows;
    final cellCount = columns * rows;

    for (var index = 0; index < cellCount; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final rect = Rect.fromLTWH(
        gridLeft + column * (cellWidth + horizontalGap),
        gridTop + row * (cellHeight + verticalGap),
        cellWidth,
        cellHeight,
      );
      if (index < dates.length) {
        final date = dates[index];
        _drawDayCard(
          canvas,
          rect,
          doodle: doodles[dateKey(date)],
          label: labelForDate(date),
          seed: seed + index * 17,
          roomy: columns == 2,
        );
      } else if (index == cellCount - 1) {
        _drawLogoCard(canvas, rect, logo, seed: seed + index * 17);
      } else {
        _drawDayCard(
          canvas,
          rect,
          doodle: null,
          label: '',
          seed: seed + index * 17,
          roomy: columns == 2,
        );
      }
    }

    return _encode(recorder, _storyWidth, _storyHeight);
  }

  static void _drawBackground(Canvas canvas, Size size, int seed) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _page);
    final random = math.Random(seed);
    final grain = Paint()
      ..color = const Color(0xFF756A51).withValues(alpha: .07);
    for (var index = 0; index < (size.width * size.height / 1550); index++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, random.nextDouble() * .8 + .25, grain);
    }
  }

  static void _drawSpiral(
    Canvas canvas,
    double width, {
    required double top,
    required double spacing,
    required double scale,
  }) {
    final paint = Paint()
      ..color = _mutedInk.withValues(alpha: .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * scale
      ..strokeCap = StrokeCap.round;
    for (double x = 20; x < width - 10; x += spacing) {
      final path = Path()
        ..moveTo(x + 8 * scale, top + 27 * scale)
        ..cubicTo(
          x - scale,
          top + 5 * scale,
          x + 2 * scale,
          top - 9 * scale,
          x + 13 * scale,
          top - 9 * scale,
        )
        ..cubicTo(
          x + 27 * scale,
          top - 9 * scale,
          x + 28 * scale,
          top + 7 * scale,
          x + 24 * scale,
          top + 34 * scale,
        )
        ..quadraticBezierTo(
          x + 22 * scale,
          top + 42 * scale,
          x + 27 * scale,
          top + 45 * scale,
        );
      canvas.drawPath(path, paint);
    }
  }

  static void _drawBrand(
    Canvas canvas,
    ui.Image logo,
    Offset origin, {
    bool compact = false,
  }) {
    final iconSize = compact ? 70.0 : 76.0;
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(origin.dx, origin.dy, iconSize, iconSize),
      image: logo,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    final textOrigin = Offset(origin.dx + iconSize + 18, origin.dy + 8);
    _drawBrushStroke(
      canvas,
      Rect.fromLTWH(textOrigin.dx - 4, origin.dy + 52, 258, 24),
      _yellow,
      seed: 14,
    );
    _paintText(
      canvas,
      'Drawn Days',
      textOrigin,
      fontSize: compact ? 49 : 54,
      color: _ink,
      maxWidth: 300,
      weight: FontWeight.w600,
    );
  }

  static void _drawDayCard(
    Canvas canvas,
    Rect rect, {
    required Doodle? doodle,
    required String label,
    required int seed,
    required bool roomy,
  }) {
    final rotations = roomy
        ? const [-.012, .009, -.007, .013]
        : const [-.009, .006, -.004, .008];
    final angle = rotations[seed.abs() % rotations.length];
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..rotate(angle)
      ..translate(-rect.center.dx, -rect.center.dy);
    final paperPath = _paperPath(rect, seed);
    canvas.drawPath(
      paperPath.shift(const Offset(5, 7)),
      Paint()..color = const Color(0xFF263D35).withValues(alpha: .13),
    );
    canvas.drawPath(paperPath, Paint()..color = _paper);
    canvas.drawPath(
      paperPath,
      Paint()
        ..color = _grid.withValues(alpha: .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roomy ? 2.6 : 1.8
        ..strokeCap = StrokeCap.round,
    );

    if (doodle != null && !doodle.isEmpty) {
      canvas
        ..save()
        ..clipPath(paperPath)
        ..translate(rect.left, rect.top + (roomy ? 10 : 5));
      DoodlePainter(
        doodle: doodle,
        cacheGeometry: false,
      ).paint(canvas, Size(rect.width, rect.height - (roomy ? 10 : 5)));
      canvas.restore();
    }

    if (label.isNotEmpty) {
      _paintText(
        canvas,
        label,
        Offset(rect.left + (roomy ? 19 : 11), rect.top + (roomy ? 12 : 6)),
        fontSize: roomy ? 35 : 24,
        color: _ink,
        maxWidth: rect.width - (roomy ? 38 : 22),
        weight: FontWeight.w600,
      );
    }
    _drawTape(canvas, rect, seed, roomy: roomy);
    canvas.restore();
  }

  static void _drawLogoCard(
    Canvas canvas,
    Rect rect,
    ui.Image logo, {
    required int seed,
  }) {
    _drawDayCard(
      canvas,
      rect,
      doodle: null,
      label: '',
      seed: seed,
      roomy: rect.width > 300,
    );
    final size = math.min(rect.width, rect.height) * .55;
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: rect.center, width: size, height: size),
      image: logo,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }

  static void _drawLargeTodayCard(
    Canvas canvas,
    Rect rect, {
    required DateTime date,
    required Doodle doodle,
    required AppLanguage language,
    required int seed,
  }) {
    final path = _paperPath(rect, seed);
    canvas.drawPath(
      path.shift(const Offset(8, 11)),
      Paint()..color = const Color(0xFF263D35).withValues(alpha: .15),
    );
    canvas.drawPath(path, Paint()..color = _paper);
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink.withValues(alpha: .88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    _drawBrushStroke(
      canvas,
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + 5),
        width: 210,
        height: 46,
      ),
      _yellow.withValues(alpha: .78),
      seed: seed,
    );
    _paintText(
      canvas,
      longDate(date, language),
      Offset(rect.left + 36, rect.top + 34),
      fontSize: 39,
      color: _mutedInk,
      maxWidth: rect.width - 260,
    );
    final drawingRect = Rect.fromLTRB(
      rect.left + 32,
      rect.top + 104,
      rect.right - 32,
      rect.bottom - 25,
    );
    canvas
      ..save()
      ..clipPath(path)
      ..translate(drawingRect.left, drawingRect.top);
    DoodlePainter(
      doodle: doodle,
      cacheGeometry: false,
    ).paint(canvas, drawingRect.size);
    canvas.restore();
  }

  static Path _paperPath(Rect rect, int seed) {
    final jitter = (seed % 5 - 2) * .7;
    return Path()
      ..moveTo(rect.left + 5, rect.top + 2 + jitter)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top - 1,
        rect.right - 4,
        rect.top + 4,
      )
      ..quadraticBezierTo(
        rect.right + 1,
        rect.center.dy,
        rect.right - 3,
        rect.bottom - 4,
      )
      ..quadraticBezierTo(
        rect.center.dx,
        rect.bottom + 2,
        rect.left + 4,
        rect.bottom - 2,
      )
      ..quadraticBezierTo(
        rect.left - 1,
        rect.center.dy,
        rect.left + 5,
        rect.top + 2 + jitter,
      )
      ..close();
  }

  static void _drawTape(
    Canvas canvas,
    Rect rect,
    int seed, {
    required bool roomy,
  }) {
    final colors = [_yellow, _blueTape, _greenTape, _pinkTape];
    final width = roomy ? 118.0 : 69.0;
    final height = roomy ? 25.0 : 16.0;
    final left = rect.left + rect.width * (.32 + (seed % 3) * .09);
    _drawBrushStroke(
      canvas,
      Rect.fromLTWH(left, rect.top - height * .28, width, height),
      colors[seed.abs() % colors.length].withValues(alpha: .82),
      seed: seed,
    );
  }

  static void _drawBrushStroke(
    Canvas canvas,
    Rect rect,
    Color color, {
    required int seed,
  }) {
    final wobble = (seed % 5 - 2) * .7;
    final path = Path()
      ..moveTo(rect.left + 2, rect.top + 3 + wobble)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top - 1,
        rect.right - 2,
        rect.top + 4,
      )
      ..lineTo(rect.right, rect.bottom - 4)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.bottom + 1,
        rect.left,
        rect.bottom - 2,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  static void _drawWobblyUnderline(
    Canvas canvas,
    Offset start,
    double width,
    Color color, {
    required int seed,
    required double strokeWidth,
  }) {
    final wobble = (seed % 7 - 3) * .55;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + width * .28,
        start.dy - 8 + wobble,
        start.dx + width * .58,
        start.dy + 7 - wobble,
        start.dx + width,
        start.dy - 1,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    required double maxWidth,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'PatrickHand',
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
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
