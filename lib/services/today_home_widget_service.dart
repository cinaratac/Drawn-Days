import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../utils/calendar_utils.dart';
import '../widgets/doodle_painter.dart';

class TodayHomeWidgetService {
  TodayHomeWidgetService._();

  static const appGroupId = 'group.com.dairry.dairryapp';
  static const androidProvider = 'DairryTodayWidgetProvider';
  static const androidQualifiedProvider =
      'com.dairry.dairryapp.DairryTodayWidgetProvider';
  static const iOSWidgetKind = 'DairryTodayWidget';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (error, stackTrace) {
      // A native plugin added during a debug session becomes available after
      // a full restart. The main calendar must remain usable in the meantime.
      debugPrint('Today widget initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> sync({
    required DateTime date,
    required Doodle? doodle,
    required AppLanguage language,
  }) async {
    await initialize();
    try {
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

      if (doodle != null) {
        await HomeWidget.renderFlutterWidget(
          _WidgetDoodleArtwork(doodle: doodle),
          key: 'today_doodle',
          logicalSize: const Size.square(320),
          pixelRatio: 2,
          appGroupId: appGroupId,
        );
      } else {
        await HomeWidget.saveWidgetData<String>(
          'today_doodle',
          null,
          appGroupId: appGroupId,
        );
      }

      await HomeWidget.updateWidget(
        name: androidProvider,
        androidName: androidProvider,
        qualifiedAndroidName: androidQualifiedProvider,
        iOSName: iOSWidgetKind,
      );
    } catch (error, stackTrace) {
      // Widget sync is supplementary and must never interrupt drawing saves.
      debugPrint('Today widget sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _WidgetDoodleArtwork extends StatelessWidget {
  const _WidgetDoodleArtwork({required this.doodle});

  final Doodle doodle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 320,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CustomPaint(
            painter: DoodlePainter(doodle: doodle, stickerOutline: false),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
