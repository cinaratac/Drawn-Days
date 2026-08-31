import 'package:flutter/material.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
import 'add_doodle_prompt.dart';
import 'doodle_painter.dart';

class WeekCalendar extends StatelessWidget {
  const WeekCalendar({
    super.key,
    required this.focusDate,
    required this.today,
    required this.todayRequest,
    required this.isActive,
    required this.doodles,
    required this.onDayTap,
    required this.language,
    required this.mondayFirst,
  });

  final DateTime focusDate;
  final DateTime today;
  final int todayRequest;
  final bool isActive;
  final Map<String, Doodle> doodles;
  final ValueChanged<DateTime> onDayTap;
  final AppLanguage language;
  final bool mondayFirst;

  static const _spacing = 8.0;
  static const _navigationClearance = 90.0;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(focusDate, mondayFirst: mondayFirst);
    final dates = List<DateTime>.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return StretchingOverscrollIndicator(
          axisDirection: AxisDirection.down,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  _navigationClearance,
                ),
                child: Column(
                  children: List<Widget>.generate(4, (row) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: row == 3 ? 0 : _spacing,
                        ),
                        child: Row(
                          children: List<Widget>.generate(2, (column) {
                            final index = (row * 2) + column;
                            if (index >= dates.length) {
                              return const Expanded(child: SizedBox.expand());
                            }

                            final date = dates[index];
                            final future = isAfterDay(date, today);
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: column == 0 ? _spacing : 0,
                                ),
                                child: RepaintBoundary(
                                  child: _WeekDayCard(
                                    key: Key('day-${dateKey(date)}'),
                                    date: date,
                                    today: isSameDay(date, today),
                                    future: future,
                                    doodle: doodles[dateKey(date)],
                                    onTap: future ? null : () => onDayTap(date),
                                    language: language,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    super.key,
    required this.date,
    required this.today,
    required this.future,
    required this.doodle,
    required this.onTap,
    required this.language,
  });

  final DateTime date;
  final bool today;
  final bool future;
  final Doodle? doodle;
  final VoidCallback? onTap;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final scale = (shortSide / 230).clamp(0.58, 0.78).toDouble();
        final horizontalInset = 16 * scale;
        final topInset = 14 * scale;
        final dateFontSize = (13 * scale).clamp(9.0, 13.0).toDouble();

        return Material(
          color: Colors.white,
          elevation: future ? 0 : 1,
          shadowColor: const Color(0x20000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: today ? colors.primary : const Color(0xFFDFE3DF),
              width: today ? 1.6 : 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: doodle == null
                      ? Center(
                          child: future
                              ? Icon(
                                  Icons.lock_outline_rounded,
                                  color: const Color(0xFF9AA39D),
                                  size: 30 * scale,
                                )
                              : AddDoodlePrompt(
                                  language: language,
                                  onTap: onTap,
                                  scale: scale,
                                ),
                        )
                      : Opacity(
                          opacity: future ? 0.35 : 1,
                          child: DoodlePreview(
                            doodle: doodle!,
                            padding: EdgeInsets.fromLTRB(
                              18 * scale,
                              42 * scale,
                              18 * scale,
                              18 * scale,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: horizontalInset,
                  top: topInset,
                  child: Text(
                    '${date.day} ${monthNames(language)[date.month - 1]}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: future
                          ? const Color(0xFF9EA59F)
                          : today
                          ? colors.primary
                          : const Color(0xFF4F5751),
                      fontSize: dateFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Positioned(
                  right: horizontalInset,
                  top: topInset,
                  child: Text(
                    compactWeekdayName(date, language),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: future
                          ? const Color(0xFF9EA59F)
                          : today
                          ? colors.primary
                          : const Color(0xFF4F5751),
                      fontSize: dateFontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
