import 'package:drawn_days/models/app_settings.dart';
import 'package:drawn_days/services/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('provides all reminder messages in both languages', () {
    expect(dailyReminderMessages, hasLength(12));

    for (final message in dailyReminderMessages) {
      expect(message.forLanguage(AppLanguage.turkish), isNotEmpty);
      expect(message.forLanguage(AppLanguage.english), isNotEmpty);
    }
  });

  test('selects a stable message for a calendar date', () {
    final date = DateTime(2026, 8, 22);

    expect(reminderMessageForDate(date), same(reminderMessageForDate(date)));
    expect(
      dailyReminderMessages,
      contains(reminderMessageForDate(date.add(const Duration(days: 1)))),
    );
  });

  test('defaults reminders to 18:00', () {
    const settings = AppSettings();

    expect(settings.language, AppLanguage.english);
    expect(settings.dailyReminderEnabled, isTrue);
    expect(settings.reminderHour, 18);
    expect(settings.reminderMinute, 0);
  });

  test('uses the reminder time selected in settings', () {
    final settings = const AppSettings().copyWith(
      reminderHour: 21,
      reminderMinute: 35,
    );
    final scheduled = reminderTimeForDate(
      DateTime(2026, 8, 22),
      settings,
      location: tz.getLocation('Europe/Istanbul'),
    );

    expect(scheduled.hour, 21);
    expect(scheduled.minute, 35);
    expect(scheduled.location.name, 'Europe/Istanbul');
  });
}
