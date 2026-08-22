import 'package:flutter/material.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
import 'doodle_painter.dart';

class WeekCalendar extends StatefulWidget {
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

  @override
  State<WeekCalendar> createState() => _WeekCalendarState();
}

class _WeekCalendarState extends State<WeekCalendar> {
  static const _daySpacing = 8.0;

  final ScrollController _scrollController = ScrollController();
  double _itemExtent = 0;

  @override
  void didUpdateWidget(covariant WeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final todayRequested = oldWidget.todayRequest != widget.todayRequest;
    final oldWeek = startOfWeek(
      oldWidget.focusDate,
      mondayFirst: oldWidget.mondayFirst,
    );
    final newWeek = startOfWeek(
      widget.focusDate,
      mondayFirst: widget.mondayFirst,
    );
    if (!todayRequested && isSameDay(oldWeek, newWeek)) {
      return;
    }

    final targetIndex = todayRequested
        ? (widget.mondayFirst
              ? widget.today.weekday - 1
              : widget.today.weekday % 7)
        : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _itemExtent <= 0) {
        return;
      }
      final targetOffset = (targetIndex * _itemExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      if (!widget.isActive) {
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(
      widget.focusDate,
      mondayFirst: widget.mondayFirst,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSide = constraints.maxWidth;
        _itemExtent = squareSide + _daySpacing;
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: 7,
          itemExtent: _itemExtent,
          cacheExtent: _itemExtent,
          itemBuilder: (context, index) {
            final date = weekStart.add(Duration(days: index));
            final future = isAfterDay(date, widget.today);
            return Padding(
              padding: const EdgeInsets.only(bottom: _daySpacing),
              child: SizedBox.square(
                dimension: squareSide,
                child: RepaintBoundary(
                  child: _WeekDayCard(
                    key: Key('day-${dateKey(date)}'),
                    date: date,
                    today: isSameDay(date, widget.today),
                    future: future,
                    doodle: widget.doodles[dateKey(date)],
                    onTap: future ? null : () => widget.onDayTap(date),
                    language: widget.language,
                  ),
                ),
              ),
            );
          },
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
                      child: Icon(
                        future ? Icons.lock_outline_rounded : Icons.add_rounded,
                        color: future
                            ? const Color(0xFF9AA39D)
                            : const Color(0xFFD8D0C4),
                        size: 30,
                      ),
                    )
                  : Opacity(
                      opacity: future ? 0.35 : 1,
                      child: DoodlePreview(
                        doodle: doodle!,
                        padding: const EdgeInsets.fromLTRB(18, 42, 18, 18),
                      ),
                    ),
            ),
            Positioned(
              left: 16,
              top: 14,
              child: Text(
                '${date.day} ${monthNames(language)[date.month - 1]}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: future
                      ? const Color(0xFF9EA59F)
                      : today
                      ? colors.primary
                      : const Color(0xFF4F5751),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
