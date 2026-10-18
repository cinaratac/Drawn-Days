import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import 'day_tap_callback.dart';
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
  final DayTapCallback onDayTap;
  final AppLanguage language;
  final bool mondayFirst;

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(focusDate, mondayFirst: mondayFirst);
    final dates = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 78),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: List.generate(
                  3,
                  (row) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: row == 2 ? 0 : _spacing),
                      child: Row(
                        children: List.generate(2, (column) {
                          final index = row * 2 + column;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: column == 0 ? _spacing : 0,
                              ),
                              child: _WeekDayCard(
                                key: Key('day-${dateKey(dates[index])}'),
                                date: dates[index],
                                today: isSameDay(dates[index], today),
                                future: isAfterDay(dates[index], today),
                                doodle: doodles[dateKey(dates[index])],
                                onDayTap: onDayTap,
                                language: language,
                                tapeColor: _tapeColors[index],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _spacing),
            SizedBox(
              height: (constraints.maxHeight * .22).clamp(116.0, 142.0),
              child: _WeekDayCard(
                key: Key('day-${dateKey(dates[6])}'),
                date: dates[6],
                today: isSameDay(dates[6], today),
                future: isAfterDay(dates[6], today),
                doodle: doodles[dateKey(dates[6])],
                onDayTap: onDayTap,
                language: language,
                tapeColor: _tapeColors[6],
                large: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _tapeColors = <Color>[
  Color(0xFFF2D762),
  Color(0xFFE8B6A4),
  Color(0xFFB8D5E5),
  Color(0xFFE8B6A4),
  Color(0xFFF2D762),
  Color(0xFFB8D7C4),
  Color(0xFFF2D762),
];

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    super.key,
    required this.date,
    required this.today,
    required this.future,
    required this.doodle,
    required this.onDayTap,
    required this.language,
    required this.tapeColor,
    this.large = false,
  });

  final DateTime date;
  final bool today;
  final bool future;
  final Doodle? doodle;
  final DayTapCallback onDayTap;
  final AppLanguage language;
  final Color tapeColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final empty = doodle == null;
    final interactive = !future;
    const doodlePadding = EdgeInsets.all(3);
    return Builder(
      builder: (context) {
        void handleTap() {
          if (!interactive) return;
          final box = context.findRenderObject();
          if (box is! RenderBox || !box.hasSize) return;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          onDayTap(date, doodlePreviewPaintRect(rect, doodlePadding));
        }

        return Opacity(
          opacity: future ? .48 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: interactive ? handleTap : null,
              borderRadius: BorderRadius.circular(11),
              child: CustomPaint(
                painter: _WeekCardPainter(
                  dashed: empty && !large,
                  emphasized: large,
                  surface: context.drawnTheme.paper,
                  ink: context.drawnTheme.ink,
                  muted: context.drawnTheme.grid,
                  shadow: context.drawnTheme.shadow,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (!empty)
                      Positioned.fill(
                        child: DoodlePreview(
                          doodle: doodle!,
                          padding: doodlePadding,
                        ),
                      ),
                    if (empty && !large)
                      Positioned.fill(
                        child: _EmptyDayPrompt(
                          language: language,
                          enabled: interactive,
                        ),
                      ),
                    if (empty && large)
                      Positioned(
                        left: 130,
                        right: 72,
                        top: 18,
                        bottom: 18,
                        child: CustomPaint(
                          painter: _WeekFacePainter(
                            color: context.drawnTheme.ink,
                          ),
                        ),
                      ),
                    Positioned(
                      left: large ? 17 : 10,
                      top: large ? 15 : 8,
                      child: _DateLabel(
                        date: date,
                        language: language,
                        large: large,
                      ),
                    ),
                    if (today)
                      Positioned(
                        left: large ? 22 : 10,
                        bottom: large ? 27 : 7,
                        child: _TodayLabel(language: language),
                      ),
                    if (!empty && !large)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: -5,
                        child: Center(child: _TapeStrip(color: tapeColor)),
                      ),
                    if (large)
                      Positioned(
                        right: 15,
                        bottom: 14,
                        child: _EditButton(
                          onTap: interactive ? handleTap : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({
    required this.date,
    required this.language,
    required this.large,
  });
  final DateTime date;
  final AppLanguage language;
  final bool large;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${date.day}',
        style: TextStyle(
          color: context.drawnTheme.ink,
          fontFamily: 'PatrickHand',
          fontSize: large ? 39 : 21,
          height: .9,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 5),
      Padding(
        padding: EdgeInsets.only(bottom: large ? 2 : 0),
        child: Text(
          compactWeekdayName(date, language),
          style: TextStyle(
            color: context.drawnTheme.mutedInk,
            fontFamily: 'PatrickHand',
            fontSize: large ? 17 : 15,
            height: 1,
          ),
        ),
      ),
    ],
  );
}

class _EmptyDayPrompt extends StatelessWidget {
  const _EmptyDayPrompt({required this.language, required this.enabled});
  final AppLanguage language;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 112;
      final buttonSize = compact ? 36.0 : 48.0;
      return Padding(
        padding: EdgeInsets.only(top: compact ? 18 : 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: context.drawnTheme.paper,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1753605A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_outlined,
                color: enabled
                    ? const Color(0xFF2E704F)
                    : const Color(0xFF8C958F),
                size: compact ? 19 : 23,
              ),
            ),
            SizedBox(height: compact ? 2 : 5),
            Text(
              language == AppLanguage.english
                  ? 'Draw something'
                  : 'Bir şey çiz',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.drawnTheme.mutedInk,
                fontFamily: 'PatrickHand',
                fontSize: compact ? 13 : 15,
                height: 1,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF2E704F),
    elevation: 5,
    shadowColor: const Color(0x55304038),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: const SizedBox.square(
        dimension: 47,
        child: Icon(Icons.edit_outlined, color: Colors.white, size: 22),
      ),
    ),
  );
}

class _TodayLabel extends StatelessWidget {
  const _TodayLabel({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const SizedBox(
        width: 51,
        height: 17,
        child: CustomPaint(
          painter: _TapeStrokePainter(color: Color(0xFFF2D762)),
        ),
      ),
      Text(
        language == AppLanguage.english ? 'today' : 'bugün',
        style: const TextStyle(
          color: Color(0xFF173F32),
          fontFamily: 'PatrickHand',
          fontSize: 17,
          height: 1,
        ),
      ),
    ],
  );
}

class _TapeStrip extends StatelessWidget {
  const _TapeStrip({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.035,
    child: Container(
      width: 42,
      height: 14,
      color: color.withValues(alpha: .82),
    ),
  );
}

class _WeekCardPainter extends CustomPainter {
  const _WeekCardPainter({
    required this.dashed,
    required this.emphasized,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.shadow,
  });
  final bool dashed;
  final bool emphasized;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(11, 2)
      ..cubicTo(size.width * .35, 1, size.width * .72, 3, size.width - 10, 2)
      ..cubicTo(size.width - 3, 4, size.width - 2, 9, size.width - 2, 15)
      ..lineTo(size.width - 3, size.height - 11)
      ..cubicTo(
        size.width - 3,
        size.height - 4,
        size.width - 9,
        size.height - 2,
        size.width - 15,
        size.height - 2,
      )
      ..lineTo(12, size.height - 2)
      ..cubicTo(5, size.height - 3, 3, size.height - 8, 3, size.height - 14)
      ..lineTo(2, 13)
      ..cubicTo(2, 6, 5, 3, 11, 2)
      ..close();
    if (!dashed) {
      canvas.drawShadow(path, shadow, emphasized ? 4 : 5, false);
      canvas.drawPath(path, Paint()..color = surface);
    }
    final border = Paint()
      ..color = emphasized ? ink : muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasized ? 2.6 : 1.5
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      if (emphasized) canvas.drawPath(path, border);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          border,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekCardPainter oldDelegate) =>
      oldDelegate.dashed != dashed ||
      oldDelegate.emphasized != emphasized ||
      oldDelegate.surface != surface ||
      oldDelegate.ink != ink ||
      oldDelegate.muted != muted ||
      oldDelegate.shadow != shadow;
}

class _TapeStrokePainter extends CustomPainter {
  const _TapeStrokePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(1, size.height * .25)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - 2, size.height * .78)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color.withValues(alpha: .88),
    );
  }

  @override
  bool shouldRepaint(covariant _TapeStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WeekFacePainter extends CustomPainter {
  const _WeekFacePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .12, size.height * .35)
        ..quadraticBezierTo(
          size.width * .23,
          size.height * .13,
          size.width * .38,
          size.height * .30,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .62, size.height * .28)
        ..quadraticBezierTo(
          size.width * .78,
          size.height * .16,
          size.width * .91,
          size.height * .34,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .29, size.height * .69)
        ..quadraticBezierTo(
          size.width * .52,
          size.height * .87,
          size.width * .79,
          size.height * .68,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _WeekFacePainter oldDelegate) =>
      oldDelegate.color != color;
}
