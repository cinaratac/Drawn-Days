import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
import 'day_tap_callback.dart';
import 'doodle_painter.dart';

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
  static const _navigationClearance = 90.0;
  static const _monthHeaderExtent = 92.0;
  static const _gridTopOffset = 92.0;
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
    final cellSize = (_itemExtent - _monthHeaderExtent) / _monthGridRowCount;
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
        final contentWidth = constraints.maxWidth;
        final cellSize = contentWidth / 7;
        final gridHeight = cellSize * 6;
        final monthHeight = _monthHeaderExtent + gridHeight;
        _itemExtent = monthHeight;
        _viewportHeight = constraints.maxHeight;

        if (!_initialPositionApplied) {
          _initialPositionApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final initialIndex = _indexFor(widget.month);
            _visibleMonthIndex = initialIndex;
            _scrollController.jumpTo(
              _offsetFor(
                initialIndex,
                alignAtBottom: initialIndex == _currentMonthIndex,
              ),
            );
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

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 22, child: _NotebookBinding()),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 23, right: 3),
                child: Text(
                  monthTitle(month, language),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDFE3DF), width: 0.8),
            ),
            child: Row(
              children: weekdayNamesShort(language, mondayFirst: mondayFirst)
                  .map(
                    (weekday) => Expanded(
                      child: Center(
                        child: Text(
                          weekday.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.45,
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
                child: Column(
                  children: List<Widget>.generate(rowCount, (row) {
                    return SizedBox(
                      height: cellSize,
                      child: Row(
                        children: List<Widget>.generate(7, (column) {
                          final index = (row * 7) + column;
                          final dayNumber = index - leadingEmptyCells + 1;
                          if (dayNumber < 1 || dayNumber > dayCount) {
                            return const Expanded(child: _EmptyMonthDayCell());
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
                              future: future,
                              doodle: doodles[key],
                              onTap: future
                                  ? null
                                  : (targetRect) => onDayTap(date, targetRect),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyMonthDayCell extends StatelessWidget {
  const _EmptyMonthDayCell();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFDFE3DF), width: 0.8),
        ),
      ),
    );
  }
}

class _NotebookBinding extends StatelessWidget {
  const _NotebookBinding();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _NotebookBindingPainter(color: Color(0xFF3E423F)),
      child: const SizedBox.expand(),
    );
  }
}

class _NotebookBindingPainter extends CustomPainter {
  const _NotebookBindingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final railPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    final capPaint = Paint()..color = color.withValues(alpha: 0.88);
    final tabPaint = Paint()..color = color.withValues(alpha: 0.66);
    final wirePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shadowPaint = Paint()..color = color.withValues(alpha: 0.08);
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.82);

    canvas.drawLine(Offset(0, 5.2), Offset(size.width, 5.2), railPaint);
    canvas.drawLine(Offset(0, 15.4), Offset(size.width, 15.4), railPaint);

    final ringCount = (size.width / 13).floor().clamp(14, 32).toInt();
    final gap = size.width / ringCount;
    for (var index = 0; index < ringCount; index++) {
      final x = gap * (index + 0.5);
      final capRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 3.4), width: 4.2, height: 6.2),
        const Radius.circular(1.2),
      );
      final tabRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, 12.6), width: 3.6, height: 9.8),
        const Radius.circular(1),
      );

      canvas.drawRRect(tabRect.shift(const Offset(0, 0.9)), shadowPaint);
      canvas.drawRRect(tabRect, tabPaint);
      canvas.drawRRect(capRect, capPaint);
      canvas.drawCircle(Offset(x, 15.9), 1.15, shinePaint);

      final wire = Path()
        ..moveTo(x - 3.7, 2.3)
        ..cubicTo(x - 4.6, 6.5, x - 4.6, 12.8, x - 2.2, 16.0)
        ..quadraticBezierTo(x, 18.6, x + 2.2, 16.0)
        ..cubicTo(x + 4.6, 12.8, x + 4.6, 6.5, x + 3.7, 2.3);
      canvas.drawPath(wire, wirePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookBindingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    super.key,
    required this.date,
    required this.today,
    required this.future,
    required this.doodle,
    required this.onTap,
  });

  final DateTime date;
  final bool today;
  final bool future;
  final Doodle? doodle;
  final ValueChanged<Rect>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: !future,
      enabled: !future,
      label: future ? '${date.day}, henüz yaşanmadı' : '${date.day}',
      child: Builder(
        builder: (context) {
          void handleTap() {
            final callback = onTap;
            if (callback == null) return;
            final renderObject = context.findRenderObject();
            if (renderObject is! RenderBox || !renderObject.hasSize) return;
            callback(
              renderObject.localToGlobal(Offset.zero) & renderObject.size,
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : handleTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.fromBorderSide(
                  BorderSide(
                    color: today ? colors.primary : const Color(0xFFDFE3DF),
                    width: today ? 1.6 : 0.8,
                  ),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (doodle != null)
                    Positioned.fill(
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
                            ? const Color(0xFF9EA59F)
                            : today
                            ? colors.primary
                            : const Color(0xFF5C625D),
                        fontWeight: today ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (future)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: Color(0xFF9AA39D),
                        ),
                      ),
                    ),
                  if (today && doodle == null)
                    Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
