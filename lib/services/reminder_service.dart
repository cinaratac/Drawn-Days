import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';

abstract interface class ReminderService {
  Future<void> initialize();
  Future<bool> apply(AppSettings settings);
}

class LocalReminderService implements ReminderService {
  static const _notificationId = 1707;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _nativePluginsAvailable = true;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } on MissingPluginException {
      // Native dependencies added during a running debug session are not
      // registered by hot restart. Keep the calendar usable until a full run.
      _nativePluginsAvailable = false;
    } on ArgumentError {
      // A rare platform timezone identifier may not exist in the bundled
      // database. Notifications remain disabled instead of blocking startup.
      _nativePluginsAvailable = false;
    }
    _initialized = true;
  }

  @override
  Future<bool> apply(AppSettings settings) async {
    await initialize();
    if (!_nativePluginsAvailable) return !settings.dailyReminderEnabled;
    await _plugin.cancel(id: _notificationId);
    if (!settings.dailyReminderEnabled) return true;

    final allowed = await _requestPermission(settings.soundEnabled);
    if (!allowed) return false;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.reminderHour,
      settings.reminderMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final english = settings.language == AppLanguage.english;
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'dairry.',
      body: english
          ? 'What did today look like? Draw your square.'
          : 'Bugün neye benziyordu? Kareni çiz.',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          settings.soundEnabled ? 'dairry_daily_sound' : 'dairry_daily_silent',
          english ? 'Daily reminder' : 'Günlük hatırlatma',
          channelDescription: english
              ? 'A gentle daily drawing reminder'
              : 'Nazik günlük çizim hatırlatması',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: settings.soundEnabled,
          enableVibration: settings.hapticsEnabled,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: settings.soundEnabled,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  Future<bool> _requestPermission(bool sound) async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: sound);
    return android ?? ios ?? true;
  }
}

class MemoryReminderService implements ReminderService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> apply(AppSettings settings) async => true;
}
