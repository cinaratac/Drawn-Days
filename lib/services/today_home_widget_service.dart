import 'dart:typed_data';
import 'dart:ui' as ui;

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
  static const androidQualifiedProvider =
      'com.drawndays.app.DrawnDaysTodayWidgetProvider';
  static const iOSWidgetKind = 'DrawnDaysTodayWidget';
  static const _imageDimension = 512;
  static const _imagePadding = 30.0;

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
    required Doodle? doodle,
    required AppLanguage language,
  }) {
    _syncQueue = _syncQueue.then(
      (_) => _performSync(date: date, doodle: doodle, language: language),
      onError: (_) =>
          _performSync(date: date, doodle: doodle, language: language),
    );
    return _syncQueue;
  }

  static Future<void> _performSync({
    required DateTime date,
    required Doodle? doodle,
    required AppLanguage language,
  }) async {
    await initialize();
    if (!_initialized) return;

    final fingerprint = _fingerprint(date, doodle, language);
    if (_lastFingerprint == fingerprint) return;

    try {
      if (doodle != null) {
        final pngBytes = await _renderDoodlePng(doodle);
        await HomeWidget.saveFile(
          'today_doodle',
          pngBytes,
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
          doodle != null,
          appGroupId: appGroupId,
        ),
      ]);

      await HomeWidget.updateWidget(
        name: androidProvider,
        androidName: androidProvider,
        qualifiedAndroidName: androidQualifiedProvider,
        iOSName: iOSWidgetKind,
      );
      _lastFingerprint = fingerprint;
    } catch (error, stackTrace) {
      // Widget sync is supplementary and must never interrupt drawing saves.
      debugPrint('Today widget sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<Uint8List> _renderDoodlePng(Doodle doodle) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final imageSize = Size.square(_imageDimension.toDouble());
    canvas.drawRect(Offset.zero & imageSize, Paint()..color = Colors.white);
    canvas
      ..save()
      ..translate(_imagePadding, _imagePadding);
    DoodlePainter(
      doodle: doodle,
      stickerOutline: false,
    ).paint(canvas, const Size.square(_imageDimension - (_imagePadding * 2)));
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(_imageDimension, _imageDimension);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError('Widget drawing could not be encoded as PNG');
    }
    return byteData.buffer.asUint8List();
  }

  static int _fingerprint(DateTime date, Doodle? doodle, AppLanguage language) {
    var hash = Object.hash(dateKey(date), language, doodle?.strokes.length);
    for (final stroke in doodle?.strokes ?? const <DoodleStroke>[]) {
      hash = Object.hash(
        hash,
        stroke.colorValue,
        stroke.width,
        Object.hashAll(
          stroke.points.map((point) => Object.hash(point.dx, point.dy)),
        ),
      );
    }
    return hash;
  }
}
