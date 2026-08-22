import 'package:flutter/material.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
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
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onVisibleMonthChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final AppLanguage language;
  final bool mondayFirst;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  static const _navigationClearance = 90.0;
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
      final alignAtBottom = todayRequested && targetIndex == _currentMonthIndex;
      final targetOffset = _offsetFor(
        targetIndex,
        alignAtBottom: alignAtBottom,
      );
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

  void _handleScroll() {
    if (_itemExtent <= 0 || !_scrollController.hasClients) return;
    final index = _indexAtViewportCenter();
    if (index == _visibleMonthIndex) return;
    _visibleMonthIndex = index;
    widget.onVisibleMonthChanged(_monthFor(index));
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    final visibleMonth = _monthFor(_visibleMonthIndex);
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
        final monthHeight = 79 + gridHeight;
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
            cacheExtent: _itemExtent * 1.5,
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
  final ValueChanged<DateTime> onDayTap;
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
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 38,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  monthTitle(month, language),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: Row(
              children: weekdayNamesShort(language, mondayFirst: mondayFirst)
                  .map((weekday) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          weekday.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth / 7;
              final gridHeight = cellSize * rowCount;

              return SizedBox(
                height: gridHeight,
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  crossAxisCount: 7,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 1,
                  children: List<Widget>.generate(rowCount * 7, (index) {
                    final dayNumber = index - leadingEmptyCells + 1;
                    if (dayNumber < 1 || dayNumber > dayCount) {
                      return const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFFDFE3DF), width: 0.8),
                          ),
                        ),
                      );
                    }

                    final date = DateTime(month.year, month.month, dayNumber);
                    final future = isAfterDay(date, today);
                    final doodle = doodles[dateKey(date)];

                    return _MonthDayCell(
                      key: Key('day-${dateKey(date)}'),
                      date: date,
                      today: isSameDay(date, today),
                      future: future,
                      doodle: doodle,
                      onTap: future ? null : () => onDayTap(date),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = today ? colors.primary : const Color(0xFFDFE3DF);

    return Semantics(
      button: !future,
      enabled: !future,
      label: future ? '${date.day}, henüz yaşanmadı' : '${date.day}',
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: borderColor, width: today ? 1.6 : 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (doodle != null)
                Positioned.fill(
                  top: 12,
                  child: Opacity(
                    opacity: future ? 0.35 : 1,
                    child: DoodlePreview(
                      doodle: doodle!,
                      padding: const EdgeInsets.fromLTRB(3, 2, 3, 3),
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: const Color(0xFF9AA39D),
                    ),
                  ),
                ),
              if (today && doodle == null)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: colors.primary,
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
