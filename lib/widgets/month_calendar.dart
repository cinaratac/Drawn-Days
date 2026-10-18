import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
import 'day_tap_callback.dart';
import 'doodle_painter.dart';

const _calendarHorizontalInset = 2.0;

Color _accentForMonth(int month) => const <Color>[
  Color(0xFFB25F3D),
  Color(0xFF7B61A8),
  Color(0xFF3F8A68),
  Color(0xFFD18C32),
  Color(0xFFB64F63),
  Color(0xFF4A7FA7),
  Color(0xFF9C713B),
  Color(0xFF6B8D45),
  Color(0xFF8C5C9E),
  Color(0xFFB15F3C),
  Color(0xFF4A7FA7),
  Color(0xFF2F7A62),
][month - 1];

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.todayRequest,
    required this.isActive,
    required this.doodles,
    required this.onDayTap,
    required this.onVisibleMonthChanged,
    required this.onMonthChanged,
    required this.language,
    required this.mondayFirst,
  });

  final DateTime month;
  final DateTime today;
  final int todayRequest;
  final bool isActive;
  final Map<String, Doodle> doodles;
  final DayTapCallback onDayTap;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final AppLanguage language;
  final bool mondayFirst;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  static const _navigationClearance = 20.0;
  static const _monthHeaderExtent = 34.0;
  static const _nextMonthHeaderExtent = 74.0;
  static const _gridTopOffset = 34.0;
  static const _monthGridRowCount = 6;
  static const _pastMonthCount = 1200;
  static const _futureMonthCount = 1200;
  static const _monthCount = _pastMonthCount + 1 + _futureMonthCount;
  static const _currentMonthIndex = _pastMonthCount;

  final ScrollController _scrollController = ScrollController();
  double _itemExtent = 0;
  double _viewportHeight = 0;
  int _visibleMonthIndex = 0;
  bool _initialPositionApplied = false;

  @override
  void initState() {
    super.initState();
    _visibleMonthIndex = _indexFor(widget.month);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final todayRequested = oldWidget.todayRequest != widget.todayRequest;
    if (!todayRequested &&
        oldWidget.month.year == widget.month.year &&
        oldWidget.month.month == widget.month.month) {
      return;
    }

    final targetMonth = todayRequested ? widget.today : widget.month;
    final targetIndex = _indexFor(targetMonth);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _itemExtent <= 0) {
        return;
      }
      final currentIndex = _indexAtViewportCenter();
      if (!todayRequested && targetIndex == currentIndex) return;
      final targetOffset = todayRequested
          ? _offsetForDateCentered(widget.today)
          : _offsetFor(targetIndex);
      if ((targetOffset - _scrollController.offset).abs() < 1) return;
      if (todayRequested && widget.isActive) {
        final monthDistance = (currentIndex - targetIndex).abs();
        final durationMilliseconds = (450 + (monthDistance * 90))
            .clamp(550, 1400)
            .toInt();
        _scrollController.animateTo(
          targetOffset,
          duration: Duration(milliseconds: durationMilliseconds),
          curve: Curves.easeInOutCubic,
        );
        return;
      }
      if (!widget.isActive || (currentIndex - targetIndex).abs() > 1) {
        _visibleMonthIndex = targetIndex;
        _scrollController.jumpTo(targetOffset);
        return;
      }
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _indexFor(DateTime month) {
    final index =
        _currentMonthIndex +
        ((month.year - widget.today.year) * 12) +
        month.month -
        widget.today.month;
    return index.clamp(0, _monthCount - 1).toInt();
  }

  DateTime _monthFor(int index) {
    return DateTime(
      widget.today.year,
      widget.today.month + index - _currentMonthIndex,
    );
  }

  int _indexAtViewportCenter() {
    final referenceOffset = _scrollController.offset + (_viewportHeight * 0.5);
    return (referenceOffset / _itemExtent)
        .floor()
        .clamp(0, _monthCount - 1)
        .toInt();
  }

  double _offsetFor(int index, {bool alignAtBottom = false}) {
    final bottomAlignment = alignAtBottom
        ? (_viewportHeight - _navigationClearance - _itemExtent).clamp(
            0.0,
            double.infinity,
          )
        : 0.0;
    return ((index * _itemExtent) - bottomAlignment)
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
  }

  double _offsetForDateCentered(DateTime date) {
    final monthIndex = _indexFor(date);
    final firstDay = DateTime(date.year, date.month);
    final leadingEmptyCells = widget.mondayFirst
        ? firstDay.weekday - DateTime.monday
        : firstDay.weekday % 7;
    final dayIndex = leadingEmptyCells + date.day - 1;
    final rowIndex = dayIndex ~/ 7;
    final cellSize =
        (_itemExtent - _monthHeaderExtent - _nextMonthHeaderExtent) /
        _monthGridRowCount;
    final cellCenterOffset =
        _gridTopOffset + (rowIndex * cellSize) + (cellSize / 2);
    return ((monthIndex * _itemExtent) +
            cellCenterOffset -
            (_viewportHeight / 2))
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
  }

  void _handleScroll() {
    if (_itemExtent <= 0 || !_scrollController.hasClients) return;
    final index = _indexAtViewportCenter();
    if (index == _visibleMonthIndex) return;
    _visibleMonthIndex = index;
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    final visibleMonth = _monthFor(_visibleMonthIndex);
    widget.onVisibleMonthChanged(visibleMonth);
    if (visibleMonth.year != widget.month.year ||
        visibleMonth.month != widget.month.month) {
      widget.onMonthChanged(visibleMonth);
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            constraints.maxWidth - (_calendarHorizontalInset * 2);
        final cellSize = contentWidth / 7;
        final gridHeight = cellSize * 6;
        final monthHeight =
            _monthHeaderExtent + gridHeight + _nextMonthHeaderExtent;
        _itemExtent = monthHeight;
        _viewportHeight = constraints.maxHeight;

        if (!_initialPositionApplied) {
          _initialPositionApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final initialIndex = _indexFor(widget.month);
            _visibleMonthIndex = initialIndex;
            _scrollController.jumpTo(_offsetFor(initialIndex));
            widget.onVisibleMonthChanged(_monthFor(initialIndex));
          });
        }

        return NotificationListener<ScrollEndNotification>(
          onNotification: _handleScrollEnd,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: _navigationClearance),
            itemCount: _monthCount,
            itemExtent: _itemExtent,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            scrollCacheExtent: ScrollCacheExtent.pixels(_itemExtent * 1.5),
            itemBuilder: (context, index) {
              final month = _monthFor(index);
              return RepaintBoundary(
                child: _MonthPage(
                  key: ValueKey('month-${month.year}-${month.month}'),
                  month: month,
                  today: widget.today,
                  doodles: widget.doodles,
                  onDayTap: widget.onDayTap,
                  language: widget.language,
                  mondayFirst: widget.mondayFirst,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MonthPage extends StatelessWidget {
  const _MonthPage({
    super.key,
    required this.month,
    required this.today,
    required this.doodles,
    required this.onDayTap,
    required this.language,
    required this.mondayFirst,
  });

  final DateTime month;
  final DateTime today;
  final Map<String, Doodle> doodles;
  final DayTapCallback onDayTap;
  final AppLanguage language;
  final bool mondayFirst;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingEmptyCells = mondayFirst
        ? firstDay.weekday - DateTime.monday
        : firstDay.weekday % 7;
    final dayCount = daysInMonth(month);
    const rowCount = 6;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _calendarHorizontalInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: weekdayNamesShort(language, mondayFirst: mondayFirst)
                  .map(
                    (weekday) => Expanded(
                      child: Center(
                        child: Text(
                          weekday.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF53605A),
                                fontFamily: 'PatrickHand',
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth / 7;
              final gridHeight = cellSize * rowCount;

              return SizedBox(
                height: gridHeight,
                child: CustomPaint(
                  painter: const _CalendarGridPainter(),
                  child: Column(
                    children: List<Widget>.generate(rowCount, (row) {
                      return SizedBox(
                        height: cellSize,
                        child: Row(
                          children: List<Widget>.generate(7, (column) {
                            final index = (row * 7) + column;
                            final dayNumber = index - leadingEmptyCells + 1;
                            if (dayNumber < 1 || dayNumber > dayCount) {
                              return const Expanded(child: SizedBox.expand());
                            }

                            final date = DateTime(
                              month.year,
                              month.month,
                              dayNumber,
                            );
                            final future = isAfterDay(date, today);
                            final key = dateKey(date);

                            return Expanded(
                              child: _MonthDayCell(
                                key: Key('day-$key'),
                                date: date,
                                today: isSameDay(date, today),
                                row: row,
                                column: column,
                                future: future,
                                doodle: doodles[key],
                                onTap: (targetRect) {
                                  if (future) {
                                    final message =
                                        language == AppLanguage.english
                                        ? "This day hasn't happened yet."
                                        : 'Bu gün henüz yaşanmadı.';
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    return;
                                  }
                                  onDayTap(date, targetRect);
                                },
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          _NextMonthHeading(
            month: DateTime(month.year, month.month + 1),
            language: language,
          ),
        ],
      ),
    );
  }
}

class _CalendarGridPainter extends CustomPainter {
  const _CalendarGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF708079).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    for (var column = 0; column <= 7; column++) {
      final x = (size.width / 7) * column;
      final drift = column.isEven ? 1.1 : -0.8;
      final path = Path()
        ..moveTo(x + drift, -3 - (column % 3))
        ..cubicTo(
          x - drift,
          size.height * 0.30,
          x + (drift * 1.4),
          size.height * 0.68,
          x - (drift * 0.35),
          size.height + 4 + (column % 2),
        );
      canvas.drawPath(path, paint);
    }
    for (var row = 0; row <= 6; row++) {
      final y = (size.height / 6) * row;
      final drift = row.isEven ? 0.9 : -1.0;
      final path = Path()
        ..moveTo(-4 - (row % 2), y + drift)
        ..cubicTo(
          size.width * 0.28,
          y - drift,
          size.width * 0.68,
          y + (drift * 1.25),
          size.width + 5 + (row % 3),
          y - (drift * 0.25),
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NextMonthHeading extends StatelessWidget {
  const _NextMonthHeading({required this.month, required this.language});

  final DateTime month;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final monthName = monthTitle(
      month,
      language,
    ).replaceFirst(' ${month.year}', '');
    return SizedBox(
      height: 74,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 12, 3, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    monthName,
                    style: const TextStyle(
                      color: Color(0xFF173F32),
                      fontFamily: 'PatrickHand',
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${month.year}',
                    style: const TextStyle(
                      color: Color(0xFF53605A),
                      fontFamily: 'PatrickHand',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 205,
                height: 8,
                child: CustomPaint(
                  painter: _MonthUnderlinePainter(
                    color: _accentForMonth(month.month),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthUnderlinePainter extends CustomPainter {
  const _MonthUnderlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 200;
    final scaleY = size.height / 10;
    final path = Path()
      ..moveTo(3 * scaleX, 5 * scaleY)
      ..cubicTo(
        40 * scaleX,
        8 * scaleY,
        80 * scaleX,
        2 * scaleY,
        120 * scaleX,
        6 * scaleY,
      )
      ..cubicTo(
        150 * scaleX,
        8 * scaleY,
        175 * scaleX,
        3 * scaleY,
        197 * scaleX,
        5 * scaleY,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (scaleX < scaleY ? scaleX : scaleY)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MonthUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TodayOutlinePainter extends CustomPainter {
  const _TodayOutlinePainter({required this.color, required this.fillColor});

  final Color color;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 52;
    final scaleY = size.height / 64;
    final path = Path()
      ..moveTo(27 * scaleX, 2.5 * scaleY)
      ..cubicTo(
        42 * scaleX,
        1.5 * scaleY,
        50.5 * scaleX,
        12 * scaleY,
        50 * scaleX,
        32 * scaleY,
      )
      ..cubicTo(
        49.5 * scaleX,
        52 * scaleY,
        41 * scaleX,
        62.5 * scaleY,
        26 * scaleX,
        61.5 * scaleY,
      )
      ..cubicTo(
        11 * scaleX,
        62 * scaleY,
        2 * scaleX,
        51 * scaleY,
        2.5 * scaleX,
        31 * scaleY,
      )
      ..cubicTo(
        3 * scaleX,
        12 * scaleY,
        11 * scaleX,
        3 * scaleY,
        28 * scaleX,
        3.4 * scaleY,
      )
      ..cubicTo(
        33 * scaleX,
        3.5 * scaleY,
        36 * scaleX,
        4.5 * scaleY,
        39 * scaleX,
        6 * scaleY,
      );
    canvas
      ..drawPath(path, Paint()..color = fillColor)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * (scaleX < scaleY ? scaleX : scaleY)
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant _TodayOutlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    super.key,
    required this.date,
    required this.today,
    required this.row,
    required this.column,
    required this.future,
    required this.doodle,
    required this.onTap,
  });

  final DateTime date;
  final bool today;
  final int row;
  final int column;
  final bool future;
  final Doodle? doodle;
  final ValueChanged<Rect> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: true,
      label: future ? '${date.day}, henüz yaşanmadı' : '${date.day}',
      child: Builder(
        builder: (context) {
          void handleTap() {
            final renderObject = context.findRenderObject();
            if (renderObject is! RenderBox || !renderObject.hasSize) return;
            onTap(renderObject.localToGlobal(Offset.zero) & renderObject.size);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (today && doodle == null)
                  Positioned.fill(
                    left: 3,
                    top: 3,
                    right: 3,
                    bottom: 3,
                    child: CustomPaint(
                      key: const Key('today-empty-highlight'),
                      painter: _TodayOutlinePainter(
                        color: colors.primary,
                        fillColor: const Color(
                          0xFFF6D978,
                        ).withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                if (doodle != null)
                  Positioned.fill(
                    left: today ? 5 : 0,
                    top: today ? 5 : 0,
                    right: today ? 5 : 0,
                    bottom: today ? 5 : 0,
                    child: ClipRect(
                      child: DoodlePreview(
                        doodle: doodle!,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                Positioned(
                  left: 5,
                  top: 4,
                  child: Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: future
                          ? const Color(0xFFADB3AE)
                          : today
                          ? colors.primary
                          : const Color(0xFF414A44),
                      fontFamily: 'PatrickHand',
                      fontWeight: FontWeight.w400,
                      fontSize: today ? 16 : 14,
                    ),
                  ),
                ),
                if (today && doodle == null)
                  const Center(
                    child: SizedBox.square(
                      dimension: 29.365478515625,
                      child: CustomPaint(painter: _TodayPencilPainter()),
                    ),
                  ),
                if (today && doodle != null)
                  Positioned.fill(
                    child: Semantics(
                      label: 'you are here',
                      child: CustomPaint(
                        key: const Key('you-are-here-marker'),
                        painter: _YouAreHerePainter(row: row, column: column),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodayPencilPainter extends CustomPainter {
  const _TodayPencilPainter();

  static const _sourceSize = 29.365478515625;

  @override
  void paint(Canvas canvas, Size size) {
    final pencil = Path()
      ..moveTo(5, 19)
      ..lineTo(6.2, 15)
      ..lineTo(16.5, 4.8)
      ..cubicTo(17.4, 3.9, 18.9, 3.9, 19.8, 4.8)
      ..cubicTo(20.7, 5.7, 20.7, 7.2, 19.8, 8.1)
      ..lineTo(9.4, 18.4)
      ..lineTo(5, 19)
      ..close();
    final detail = Path()
      ..moveTo(14.8, 6.6)
      ..lineTo(18, 9.8);

    final scaleX = size.width / _sourceSize;
    final scaleY = size.height / _sourceSize;
    final transform = Float64List.fromList(<double>[
      1.07279 * scaleX,
      0.150771 * scaleY,
      0,
      0,
      -0.150771 * scaleX,
      1.07279 * scaleY,
      0,
      0,
      0,
      0,
      1,
      0,
      (287.358 - 283.7391357421875) * scaleX,
      (381.708 - 381.7078857421875) * scaleY,
      0,
      1,
    ]);
    final paint = Paint()
      ..color = const Color(0xFF2E5D46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * (scaleX < scaleY ? scaleX : scaleY)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(pencil.transform(transform), paint)
      ..drawPath(detail.transform(transform), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YouAreHerePainter extends CustomPainter {
  const _YouAreHerePainter({required this.row, required this.column});

  final int row;
  final int column;

  @override
  void paint(Canvas canvas, Size size) {
    const red = Color(0xFFB64F45);
    final tailOnRight = column <= 3;
    final tailBelow = row <= 2;
    final target = Offset(
      tailOnRight ? size.width - 1.2 : 1.2,
      size.height * (tailBelow ? 0.68 : 0.32),
    );
    final tail = Offset(
      target.dx + (tailOnRight ? 41 : -41),
      target.dy + (tailBelow ? 15 : -15),
    );
    final direction = target - tail;
    final directionLength = direction.distance;
    final normal = Offset(
      -direction.dy / directionLength,
      direction.dx / directionLength,
    );
    final curveSide = (tailOnRight == tailBelow) ? 1.0 : -1.0;
    final midpoint =
        Offset.lerp(tail, target, 0.52)! + (normal * (10 * curveSide));
    final controlOne = tail + (direction * 0.18) + (normal * (7 * curveSide));
    final controlTwo = midpoint - (direction * 0.12);
    final controlThree = midpoint + (direction * 0.12);
    final finalControl =
        target - (direction * 0.18) - (normal * (6 * curveSide));
    final arrowPaint = Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrow = Path()
      ..moveTo(tail.dx, tail.dy)
      ..cubicTo(
        controlOne.dx,
        controlOne.dy,
        controlTwo.dx,
        controlTwo.dy,
        midpoint.dx,
        midpoint.dy,
      )
      ..cubicTo(
        controlThree.dx,
        controlThree.dy,
        finalControl.dx,
        finalControl.dy,
        target.dx,
        target.dy,
      );
    canvas.drawPath(arrow, arrowPaint);

    final angle = math.atan2(
      target.dy - finalControl.dy,
      target.dx - finalControl.dx,
    );
    const arrowHeadLength = 10.0;
    for (final direction in const <double>[-0.62, 0.62]) {
      canvas.drawLine(
        target,
        target -
            Offset(
              math.cos(angle + direction) * arrowHeadLength,
              math.sin(angle + direction) * arrowHeadLength,
            ),
        arrowPaint,
      );
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'you are here',
        style: TextStyle(
          color: red,
          fontFamily: 'PatrickHand',
          fontSize: 16,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textOffset = Offset(
      tailOnRight ? tail.dx + 4 : tail.dx - textPainter.width - 4,
      tailBelow ? tail.dy + 5 : tail.dy - textPainter.height - 5,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _YouAreHerePainter oldDelegate) =>
      oldDelegate.row != row || oldDelegate.column != column;
}
