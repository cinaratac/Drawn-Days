import 'package:flutter/material.dart';

import '../models/app_settings.dart';

const turkishMonths = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const turkishWeekdaysShort = <String>[
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];

const turkishWeekdaysLong = <String>[
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const englishMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const englishWeekdaysShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const englishWeekdaysLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const turkishCompactWeekdays = <String>[
  'PZT',
  'SL',
  'ÇRŞ',
  'PRŞ',
  'CM',
  'CMT',
  'PZ',
];

const englishCompactWeekdays = <String>[
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

List<String> monthNames(AppLanguage language) =>
    language == AppLanguage.english ? englishMonths : turkishMonths;

List<String> weekdayNamesShort(
  AppLanguage language, {
  bool mondayFirst = true,
}) {
  final names = language == AppLanguage.english
      ? englishWeekdaysShort
      : turkishWeekdaysShort;
  return mondayFirst ? names : <String>[names.last, ...names.take(6)];
}

List<String> weekdayNamesLong(AppLanguage language) =>
    language == AppLanguage.english ? englishWeekdaysLong : turkishWeekdaysLong;

String compactWeekdayName(DateTime date, AppLanguage language) =>
    (language == AppLanguage.english
    ? englishCompactWeekdays
    : turkishCompactWeekdays)[date.weekday - 1];

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String monthTitle(
  DateTime date, [
  AppLanguage language = AppLanguage.english,
]) => '${monthNames(language)[date.month - 1]} ${date.year}';

String longDate(DateTime date, [AppLanguage language = AppLanguage.english]) {
  final months = monthNames(language);
  final weekdays = weekdayNamesLong(language);
  return language == AppLanguage.english
      ? '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}'
      : '${date.day} ${months[date.month - 1]} ${weekdays[date.weekday - 1]}';
}

DateTime startOfWeek(DateTime date, {bool mondayFirst = true}) {
  final normalized = dateOnly(date);
  final daysFromStart = mondayFirst
      ? normalized.weekday - DateTime.monday
      : normalized.weekday % 7;
  return normalized.subtract(Duration(days: daysFromStart));
}

String weekTitle(
  DateTime focusDate, {
  AppLanguage language = AppLanguage.english,
  bool mondayFirst = true,
}) {
  final months = monthNames(language);
  final start = startOfWeek(focusDate, mondayFirst: mondayFirst);
  final end = start.add(const Duration(days: 6));
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${months[start.month - 1]}';
  }
  return '${start.day} ${months[start.month - 1].substring(0, 3)} – '
      '${end.day} ${months[end.month - 1].substring(0, 3)}';
}

bool isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool isAfterDay(DateTime date, DateTime other) =>
    dateOnly(date).isAfter(dateOnly(other));

int daysInMonth(DateTime month) =>
    DateUtils.getDaysInMonth(month.year, month.month);
