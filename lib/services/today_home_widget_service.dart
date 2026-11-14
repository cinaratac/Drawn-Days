import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../utils/calendar_utils.dart';
import '../widgets/doodle_painter.dart';

class TodayHomeWidgetService {
  TodayHomeWidgetService._();

  static const appGroupId = 'group.com.drawndays.app';
  static const androidProvider = 'DrawnDaysTodayWidgetProvider';
  static const androidWeekProvider = 'DrawnDaysWeekWidgetProvider';
  static const androidMonthProvider = 'DrawnDaysMonthWidgetProvider';
  static const androidQualifiedProvider =
      'com.drawndays.app.DrawnDaysTodayWidgetProvider';
  static const androidQualifiedWeekProvider =
      'com.drawndays.app.DrawnDaysWeekWidgetProvider';
  static const androidQualifiedMonthProvider =
      'com.drawndays.app.DrawnDaysMonthWidgetProvider';
  static const iOSWidgetKind = 'DrawnDaysTodayWidget';
  static const _imageDimension = 512;
  static const _imagePadding = 30.0;
  static const _paper = Color(0xFFFFFEF8);
  static const _card = Color(0xFFFFFEF8);
  static const _ink = Color(0xFF173F32);
  static const _mutedInk = Color(0xFF53605A);
  static const _green = Color(0xFF315F46);
  static const _yellow = Color(0xFFF2D762);
  static const _terracotta = Color(0xFFB5653D);

  static bool _initialized = false;
  static int? _lastFingerprint;
  static Future<void> _syncQueue = Future<void>.value();

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (error, stackTrace) {
      debugPrint('Today widget initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> sync({
    required DateTime date,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) {
    final snapshot = Map<String, Doodle>.unmodifiable(
      doodles.map((key, value) => MapEntry(key, value.snapshot())),
    );
    _syncQueue = _syncQueue.then(
      (_) => _performSync(date: date, doodles: snapshot, language: language),
      onError: (_) =>
          _performSync(date: date, doodles: snapshot, language: language),
    );
    return _syncQueue;
  }

  static Future<void> _performSync({
    required DateTime date,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) async {
    await initialize();
    if (!_initialized) return;
    final fingerprint = _fingerprint(date, doodles, language);
    if (_lastFingerprint == fingerprint) return;

    try {
      final todayDoodle = doodles[dateKey(date)];
      if (todayDoodle != null) {
        await HomeWidget.saveFile(
          'today_doodle',
          await _renderDoodlePng(todayDoodle),
          extension: 'png',
          appGroupId: appGroupId,
        );
      } else {
        await HomeWidget.saveWidgetData<String>(
          'today_doodle',
          null,
          appGroupId: appGroupId,
        );
      }

      final artwork = await Future.wait<Uint8List>([
        renderWeekArtwork(date: date, doodles: doodles, language: language),
        renderMonthArtwork(date: date, doodles: doodles, language: language),
      ]);
      await Future.wait([
        HomeWidget.saveFile(
          'week_widget',
          artwork[0],
          extension: 'png',
          appGroupId: appGroupId,
        ),
        HomeWidget.saveFile(
          'month_widget',
          artwork[1],
          extension: 'png',
          appGroupId: appGroupId,
        ),
      ]);

      await Future.wait<bool?>([
        HomeWidget.saveWidgetData<String>(
          'today_date_key',
          dateKey(date),
          appGroupId: appGroupId,
        ),
        HomeWidget.saveWidgetData<String>(
          'widget_language',
          language.name,
          appGroupId: appGroupId,
        ),
        HomeWidget.saveWidgetData<bool>(
          'has_doodle',
          todayDoodle != null,
          appGroupId: appGroupId,
        ),
      ]);

      await _notifyWidgets();
      _lastFingerprint = fingerprint;
    } catch (error, stackTrace) {
      debugPrint('Today widget sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _notifyWidgets() async {
    if (Platform.isIOS) {
      await HomeWidget.updateWidget(
        name: iOSWidgetKind,
        iOSName: iOSWidgetKind,
      );
      return;
    }
    await Future.wait([
      _updateAndroidWidget(androidProvider, androidQualifiedProvider),
      _updateAndroidWidget(androidWeekProvider, androidQualifiedWeekProvider),
      _updateAndroidWidget(androidMonthProvider, androidQualifiedMonthProvider),
    ]);
  }

  static Future<void> _updateAndroidWidget(
    String provider,
    String qualifiedProvider,
  ) => HomeWidget.updateWidget(
    name: provider,
    androidName: provider,
    qualifiedAndroidName: qualifiedProvider,
  );

  @visibleForTesting
  static Future<Uint8List> renderWeekArtwork({
    required DateTime date,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) async {
    const size = Size(1024, 512);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintPaper(canvas, size);
    final dates = List<DateTime>.generate(
      7,
      (index) => dateOnly(date).subtract(Duration(days: 6 - index)),
    );
    final title =
        '${dates.first.day}–${dates.last.day} '
        '${monthNames(language)[date.month - 1]}';
    _paintBrand(canvas, const Offset(34, 22));
    _paintText(
      canvas,
      title,
      const Offset(34, 70),
      fontSize: 38,
      color: _ink,
      fontWeight: FontWeight.w600,
    );
    _paintWobblyLine(
      canvas,
      const Offset(34, 116),
      305,
      _terracotta,
      strokeWidth: 5,
    );

    const gap = 12.0;
    const left = 28.0;
    const top = 140.0;
    const cardHeight = 338.0;
    final cardWidth = (size.width - (left * 2) - (gap * 6)) / 7;
    for (var index = 0; index < dates.length; index++) {
      final day = dates[index];
      final rect = Rect.fromLTWH(
        left + ((cardWidth + gap) * index),
        top + (index.isEven ? 2 : -2),
        cardWidth,
        cardHeight,
      );
      _paintPaperCard(canvas, rect, seed: day.day);
      if (isSameDay(day, date)) {
        _paintWobblyBorder(canvas, rect.deflate(3), _green, 5);
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 13, rect.top - 5, 48, 13),
          Paint()..color = _yellow.withValues(alpha: .78),
        );
      }
      _paintText(
        canvas,
        '${day.day}',
        Offset(rect.left + 11, rect.top + 10),
        fontSize: 28,
        color: _ink,
        fontWeight: FontWeight.w600,
      );
      _paintText(
        canvas,
        weekdayNamesShort(language)[day.weekday - 1],
        Offset(rect.left + 45, rect.top + 17),
        fontSize: 18,
        color: _mutedInk,
      );
      final doodle = doodles[dateKey(day)];
      if (doodle != null) {
        _paintDoodle(canvas, doodle, rect.deflate(10).translate(0, 25));
      } else if (isSameDay(day, date)) {
        _paintPencil(canvas, rect.center.translate(-18, 5), 38, _green);
      }
    }
    return _encode(recorder, size);
  }

  @visibleForTesting
  static Future<Uint8List> renderMonthArtwork({
    required DateTime date,
    required Map<String, Doodle> doodles,
    required AppLanguage language,
  }) async {
    const size = Size.square(1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintPaper(canvas, size);
    _paintBrand(canvas, const Offset(38, 26));
    final title = monthTitle(date, language);
    _paintText(
      canvas,
      title,
      const Offset(38, 80),
      fontSize: 52,
      color: _ink,
      fontWeight: FontWeight.w600,
    );
    _paintWobblyLine(
      canvas,
      const Offset(40, 142),
      math.min(430, (title.length * 25).toDouble()),
      _terracotta,
      strokeWidth: 6,
    );

    const left = 30.0;
    const top = 190.0;
    const gridWidth = 964.0;
    const weekdayHeight = 46.0;
    final first = DateTime(date.year, date.month);
    final leading = first.weekday - DateTime.monday;
    final dayCount = daysInMonth(date);
    final rowCount = ((leading + dayCount) / 7).ceil();
    final cellWidth = gridWidth / 7;
    final cellHeight = (size.height - top - weekdayHeight - 34) / rowCount;
    final weekdays = weekdayNamesShort(language);
    for (var column = 0; column < 7; column++) {
      _paintText(
        canvas,
        weekdays[column],
        Offset(left + (column * cellWidth) + 8, top),
        fontSize: 25,
        color: _mutedInk,
      );
    }

    final gridTop = top + weekdayHeight;
    for (var dayNumber = 1; dayNumber <= dayCount; dayNumber++) {
      final index = leading + dayNumber - 1;
      final row = index ~/ 7;
      final column = index % 7;
      final day = DateTime(date.year, date.month, dayNumber);
      final rect = Rect.fromLTWH(
        left + (column * cellWidth),
        gridTop + (row * cellHeight),
        cellWidth,
        cellHeight,
      );
      _paintGridEdges(
        canvas,
        rect,
        row: row,
        column: column,
        lastRow: rowCount - 1,
      );
      if (isSameDay(day, date)) {
        canvas.drawOval(
          rect.deflate(7),
          Paint()..color = _yellow.withValues(alpha: .47),
        );
        _paintWobblyBorder(canvas, rect.deflate(6), _green, 5);
      }
      _paintText(
        canvas,
        '$dayNumber',
        Offset(rect.left + 7, rect.top + 5),
        fontSize: 23,
        color: isAfterDay(day, date) ? _mutedInk.withValues(alpha: .55) : _ink,
      );
      final doodle = doodles[dateKey(day)];
      if (doodle != null) {
        _paintDoodle(canvas, doodle, rect.deflate(8).translate(0, 10));
      } else if (isSameDay(day, date)) {
        _paintPencil(canvas, rect.center.translate(-12, 6), 26, _green);
      }
    }
    return _encode(recorder, size);
  }

  static void _paintPaper(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    final texture = Paint()
      ..color = const Color(0xFF796C4F).withValues(alpha: .035);
    for (var y = 9.0; y < size.height; y += 17) {
      for (var x = ((y ~/ 17).isEven ? 8.0 : 14.0); x < size.width; x += 23) {
        canvas.drawCircle(Offset(x, y), .8, texture);
      }
    }
  }

  static void _paintBrand(Canvas canvas, Offset origin) {
    canvas.drawRect(
      Rect.fromLTWH(origin.dx - 3, origin.dy + 25, 188, 20),
      Paint()..color = _yellow.withValues(alpha: .9),
    );
    _paintText(
      canvas,
      'Drawn Days',
      origin,
      fontSize: 34,
      color: _green,
      fontWeight: FontWeight.w600,
    );
    _paintPencil(canvas, origin.translate(198, 4), 25, _green);
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'PatrickHand',
          fontSize: fontSize,
          height: 1,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  static void _paintPaperCard(Canvas canvas, Rect rect, {required int seed}) {
    final shadowPath = _wobblyRect(rect.translate(4, 7), seed: seed);
    canvas.drawPath(
      shadowPath,
      Paint()..color = const Color(0xFF2B3A36).withValues(alpha: .10),
    );
    final cardPath = _wobblyRect(rect, seed: seed);
    canvas.drawPath(cardPath, Paint()..color = _card);
    canvas.drawPath(
      cardPath,
      Paint()
        ..color = const Color(0xFFD8D1C1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  static Path _wobblyRect(Rect rect, {int seed = 0}) {
    final wobble = seed.isEven ? 2.5 : -2.5;
    return Path()
      ..moveTo(rect.left + 9, rect.top + wobble)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top - wobble,
        rect.right - 8,
        rect.top + 1,
      )
      ..quadraticBezierTo(
        rect.right + wobble,
        rect.center.dy,
        rect.right - 1,
        rect.bottom - 8,
      )
      ..quadraticBezierTo(
        rect.center.dx,
        rect.bottom + wobble,
        rect.left + 8,
        rect.bottom - 1,
      )
      ..quadraticBezierTo(
        rect.left - wobble,
        rect.center.dy,
        rect.left + 1,
        rect.top + 9,
      )
      ..close();
  }

  static void _paintWobblyBorder(
    Canvas canvas,
    Rect rect,
    Color color,
    double width,
  ) {
    canvas.drawPath(
      _wobblyRect(rect, seed: rect.left.toInt()),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width,
    );
  }

  static void _paintGridEdges(
    Canvas canvas,
    Rect rect, {
    required int row,
    required int column,
    required int lastRow,
  }) {
    final paint = Paint()
      ..color = _mutedInk.withValues(alpha: .63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final hn = row.isEven ? 2.0 : -2.0;
    final vn = column.isEven ? 1.5 : -1.5;
    canvas.drawPath(
      Path()
        ..moveTo(rect.left - 3, rect.top + hn)
        ..quadraticBezierTo(
          rect.center.dx,
          rect.top - hn,
          rect.right + 3,
          rect.top + 1,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + vn, rect.top - 3)
        ..quadraticBezierTo(
          rect.left - vn,
          rect.center.dy,
          rect.left + 1,
          rect.bottom + 3,
        ),
      paint,
    );
    if (column == 6) {
      canvas.drawLine(
        rect.topRight.translate(0, -2),
        rect.bottomRight.translate(1, 3),
        paint,
      );
    }
    if (row == lastRow) {
      canvas.drawLine(
        rect.bottomLeft.translate(-2, 0),
        rect.bottomRight.translate(3, 1),
        paint,
      );
    }
  }

  static void _paintWobblyLine(
    Canvas canvas,
    Offset start,
    double length,
    Color color, {
    double strokeWidth = 4,
  }) {
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + length * .28,
          start.dy - 5,
          start.dx + length * .62,
          start.dy + 5,
          start.dx + length,
          start.dy,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  static void _paintPencil(
    Canvas canvas,
    Offset origin,
    double size,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size * .095)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(origin.dx, origin.dy + size * .72)
      ..lineTo(origin.dx + size * .12, origin.dy + size * .34)
      ..lineTo(origin.dx + size * .66, origin.dy)
      ..quadraticBezierTo(
        origin.dx + size * .84,
        origin.dy - size * .05,
        origin.dx + size * .9,
        origin.dy + size * .1,
      )
      ..quadraticBezierTo(
        origin.dx + size * .94,
        origin.dy + size * .22,
        origin.dx + size * .81,
        origin.dy + size * .31,
      )
      ..lineTo(origin.dx + size * .28, origin.dy + size * .66)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      origin.translate(size * .58, size * .08),
      origin.translate(size * .76, size * .3),
      paint,
    );
  }

  static void _paintDoodle(Canvas canvas, Doodle doodle, Rect rect) {
    canvas
      ..save()
      ..clipRect(rect)
      ..translate(rect.left, rect.top);
    DoodlePainter(
      doodle: doodle,
      stickerOutline: false,
    ).paint(canvas, rect.size);
    canvas.restore();
  }

  static Future<Uint8List> _renderDoodlePng(Doodle doodle) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final imageSize = Size.square(_imageDimension.toDouble());
    _paintPaper(canvas, imageSize);
    canvas
      ..save()
      ..translate(_imagePadding, _imagePadding);
    DoodlePainter(
      doodle: doodle,
      stickerOutline: false,
    ).paint(canvas, const Size.square(_imageDimension - (_imagePadding * 2)));
    canvas.restore();
    return _encode(recorder, imageSize);
  }

  static Future<Uint8List> _encode(
    ui.PictureRecorder recorder,
    Size size,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError('Widget artwork could not be encoded as PNG');
    }
    return byteData.buffer.asUint8List();
  }

  static int _fingerprint(
    DateTime date,
    Map<String, Doodle> doodles,
    AppLanguage language,
  ) {
    final relevantKeys = <String>{};
    final monthStart = DateTime(date.year, date.month);
    for (var index = 0; index < daysInMonth(date); index++) {
      relevantKeys.add(dateKey(monthStart.add(Duration(days: index))));
    }
    for (var index = 0; index < 7; index++) {
      relevantKeys.add(dateKey(dateOnly(date).subtract(Duration(days: index))));
    }
    final relevant = <Doodle>[];
    for (final key in relevantKeys) {
      final doodle = doodles[key];
      if (doodle != null) relevant.add(doodle);
    }
    var hash = Object.hash(dateKey(date), language, relevant.length);
    for (final doodle in relevant) {
      for (final stroke in doodle.strokes) {
        hash = Object.hash(
          hash,
          stroke.colorValue,
          stroke.width,
          Object.hashAll(
            stroke.points.map((point) => Object.hash(point.dx, point.dy)),
          ),
        );
      }
    }
    return hash;
  }
}
