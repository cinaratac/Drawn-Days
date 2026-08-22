import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';

class ReminderMessage {
  const ReminderMessage({required this.turkish, required this.english});

  final String turkish;
  final String english;

  String forLanguage(AppLanguage language) =>
      language == AppLanguage.english ? english : turkish;
}

const dailyReminderMessages = <ReminderMessage>[
  ReminderMessage(
    turkish: 'Gelecek henüz yaşanmadı, bugünü karala!',
    english: "The future hasn't happened yet—scribble today!",
  ),
  ReminderMessage(
    turkish: 'Unutma yaşıyorsun, bugün aklından ne geçiyor?',
    english: "Don't forget, you're alive. What's on your mind today?",
  ),
  ReminderMessage(
    turkish: 'Bugünü henüz karalamadın.',
    english: "You haven't scribbled today yet.",
  ),
  ReminderMessage(
    turkish: 'Nasıl hissediyorsun, bize bir karalama bırak.',
    english: 'How are you feeling? Leave us a scribble.',
  ),
  ReminderMessage(
    turkish: 'Karalanmamış günler, yaşanılmamış günler.',
    english: 'Unscribbled days are unlived days.',
  ),
  ReminderMessage(
    turkish: 'En azından bugüne bir çizgi karala. Yarını sonra düşünürüz.',
    english:
        "At least scribble a line for today. We'll think about tomorrow later.",
  ),
  ReminderMessage(
    turkish: 'Hatırlamanın iyi yolu karalamak.',
    english: 'Scribbling is a good way to remember.',
  ),
  ReminderMessage(
    turkish: 'Merhaba, bugün karalamayı unuttun sanki he?',
    english: 'Hello, looks like you forgot to scribble today, huh?',
  ),
  ReminderMessage(
    turkish: 'İyi sabahlar, iyi günler ve iyi karalamalar.',
    english: 'Good morning, good afternoon, and happy scribbling.',
  ),
  ReminderMessage(
    turkish:
        'Karalamalarına baktım da pek iyi gözükmüyorsun. Şaka yaptım, bakmadım. Çünkü bir şey karalamamışsın.',
    english:
        "I looked at your scribbles and you don't look too good. Just kidding, I didn't look—because you haven't scribbled anything.",
  ),
  ReminderMessage(
    turkish: 'Bugünkü karalaman beni benden aldı. (Hiçbir şey karalamadın.)',
    english: "Today's scribble blew me away. (You didn't scribble anything.)",
  ),
  ReminderMessage(
    turkish: 'Bugün sessiz gibisin. İstersen en azından bir çizgi karala.',
    english: "You seem quiet today. If you'd like, at least scribble a line.",
  ),
];

ReminderMessage reminderMessageForDate(DateTime date) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  // Stable across rescheduling, random-looking from one date to the next.
  final index = math.Random(seed).nextInt(dailyReminderMessages.length);
  return dailyReminderMessages[index];
}

tz.TZDateTime reminderTimeForDate(
  DateTime date,
  AppSettings settings, {
  tz.Location? location,
}) {
  return tz.TZDateTime(
    location ?? tz.local,
    date.year,
    date.month,
    date.day,
    settings.reminderHour,
    settings.reminderMinute,
  );
}

abstract interface class ReminderService {
  Stream<Uri> get launchUris;

  Future<void> initialize();

  Future<Uri?> takeInitialLaunchUri();

  Future<bool> apply(
    AppSettings settings, {
    Set<String> completedDateKeys = const <String>{},
  });

  Future<void> updateDate({
    required DateTime date,
    required bool hasDoodle,
    required AppSettings settings,
  });
}

class LocalReminderService implements ReminderService {
  static const _legacyNotificationId = 1707;
  static const _scheduleDays = 60;
  static const _payloadPrefix = 'drawndays://draw/today?reminderDate=';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<Uri> _launchController =
      StreamController<Uri>.broadcast();
  bool _initialized = false;
  Future<void>? _initialization;
  bool _nativePluginsAvailable = true;
  Uri? _initialLaunchUri;

  @override
  Stream<Uri> get launchUris => _launchController.stream;

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _performInitialization();
  }

  Future<void> _performInitialization() async {
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
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _initialLaunchUri = _uriFromPayload(
          launchDetails?.notificationResponse?.payload,
        );
      }
    } on MissingPluginException {
      _nativePluginsAvailable = false;
    } on ArgumentError {
      _nativePluginsAvailable = false;
    }
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final uri = _uriFromPayload(response.payload);
    if (uri != null) _launchController.add(uri);
  }

  Uri? _uriFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    return Uri.tryParse(payload);
  }

  @override
  Future<Uri?> takeInitialLaunchUri() async {
    await initialize();
    final uri = _initialLaunchUri;
    _initialLaunchUri = null;
    return uri;
  }

  @override
  Future<bool> apply(
    AppSettings settings, {
    Set<String> completedDateKeys = const <String>{},
  }) async {
    await initialize();
    if (!_nativePluginsAvailable) return !settings.dailyReminderEnabled;

    await _plugin.cancel(id: _legacyNotificationId);
    await _cancelDrawnDaysReminders();
    if (!settings.dailyReminderEnabled) return true;

    final allowed = await _requestPermission(settings.soundEnabled);
    if (!allowed) return false;

    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < _scheduleDays; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      if (completedDateKeys.contains(dateKey(date))) continue;
      final scheduled = _scheduledTime(date, settings);
      if (!scheduled.isAfter(now)) continue;
      await _schedule(date: date, scheduled: scheduled, settings: settings);
    }
    return true;
  }

  @override
  Future<void> updateDate({
    required DateTime date,
    required bool hasDoodle,
    required AppSettings settings,
  }) async {
    await initialize();
    if (!_nativePluginsAvailable) return;
    await _plugin.cancel(id: _notificationId(date));
    if (hasDoodle || !settings.dailyReminderEnabled) return;

    final scheduled = _scheduledTime(date, settings);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _schedule(date: date, scheduled: scheduled, settings: settings);
  }

  Future<void> _cancelDrawnDaysReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  tz.TZDateTime _scheduledTime(DateTime date, AppSettings settings) {
    return reminderTimeForDate(date, settings);
  }

  Future<void> _schedule({
    required DateTime date,
    required tz.TZDateTime scheduled,
    required AppSettings settings,
  }) async {
    final english = settings.language == AppLanguage.english;
    final message = reminderMessageForDate(date).forLanguage(settings.language);
    await _plugin.zonedSchedule(
      id: _notificationId(date),
      title: 'Drawn Days',
      body: message,
      scheduledDate: scheduled,
      payload: '$_payloadPrefix${dateKey(date)}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          settings.soundEnabled
              ? 'drawn_days_daily_sound'
              : 'drawn_days_daily_silent',
          english ? 'Daily reminder' : 'Günlük hatırlatma',
          channelDescription: english
              ? 'A daily reminder when today has not been drawn'
              : 'Bugünün çizimi yapılmadığında gelen günlük hatırlatma',
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
    );
  }

  int _notificationId(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

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
  Stream<Uri> get launchUris => const Stream<Uri>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<Uri?> takeInitialLaunchUri() async => null;

  @override
  Future<bool> apply(
    AppSettings settings, {
    Set<String> completedDateKeys = const <String>{},
  }) async => true;

  @override
  Future<void> updateDate({
    required DateTime date,
    required bool hasDoodle,
    required AppSettings settings,
  }) async {}
}
