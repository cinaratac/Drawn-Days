import 'package:flutter/material.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../utils/calendar_utils.dart';
import 'add_doodle_prompt.dart';
import 'day_tap_callback.dart';
import 'doodle_painter.dart';

class DayFlow extends StatefulWidget {
  const DayFlow({
    super.key,
    required this.today,
    required this.focusDate,
    required this.todayRequest,
    required this.isActive,
    required this.doodles,
    required this.onDayTap,
    required this.onVisibleDateChanged,
    required this.language,
  });

  final DateTime today;
  final DateTime focusDate;
  final int todayRequest;
  final bool isActive;
  final Map<String, Doodle> doodles;
  final DayTapCallback onDayTap;
  final ValueChanged<DateTime> onVisibleDateChanged;
  final AppLanguage language;

  @override
  State<DayFlow> createState() => _DayFlowState();
}

class _DayFlowState extends State<DayFlow> {
  static const _itemCount = 3650;
  static const _spacing = 8.0;

  final ScrollController _scrollController = ScrollController();
  double _itemExtent = 0;

  @override
  void didUpdateWidget(covariant DayFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focusChanged = !isSameDay(oldWidget.focusDate, widget.focusDate);
    final todayRequested = oldWidget.todayRequest != widget.todayRequest;
    if (!focusChanged && !todayRequested) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_itemExtent <= 0) return;
      final index = widget.today
          .difference(widget.focusDate)
          .inDays
          .clamp(0, _itemCount - 1)
          .toInt();
      final currentIndex = (_scrollController.offset / _itemExtent)
          .round()
          .clamp(0, _itemCount - 1)
          .toInt();
      if (!todayRequested && index == currentIndex) return;
      final targetOffset = (index * _itemExtent)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      if ((targetOffset - _scrollController.offset).abs() < 1) return;
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

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_itemExtent <= 0 || !_scrollController.hasClients) return false;
    final index = (_scrollController.offset / _itemExtent)
        .round()
        .clamp(0, _itemCount - 1)
        .toInt();
    widget.onVisibleDateChanged(widget.today.subtract(Duration(days: index)));
    return false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSide = constraints.maxWidth;
        _itemExtent = squareSide + _spacing;
        return NotificationListener<ScrollEndNotification>(
          onNotification: _handleScrollEnd,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: _spacing),
            itemBuilder: (context, index) {
              final date = widget.today.subtract(Duration(days: index));
              final doodle = widget.doodles[dateKey(date)];
              return SizedBox.square(
                dimension: squareSide,
                child: _FlowDayCard(
                  key: Key('day-${dateKey(date)}'),
                  date: date,
                  today: index == 0,
                  doodle: doodle,
                  onTap: (targetRect) => widget.onDayTap(date, targetRect),
                  language: widget.language,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FlowDayCard extends StatelessWidget {
  const _FlowDayCard({
    super.key,
    required this.date,
    required this.today,
    required this.doodle,
    required this.onTap,
    required this.language,
  });

  final DateTime date;
  final bool today;
  final Doodle? doodle;
  final ValueChanged<Rect> onTap;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const doodlePadding = EdgeInsets.fromLTRB(18, 42, 18, 18);
    return Builder(
      builder: (context) {
        void handleTap() {
          final renderObject = context.findRenderObject();
          if (renderObject is! RenderBox || !renderObject.hasSize) return;
          final cardRect =
              renderObject.localToGlobal(Offset.zero) & renderObject.size;
          onTap(doodlePreviewPaintRect(cardRect, doodlePadding));
        }

        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: today ? colors.primary : const Color(0xFFDFE3DF),
              width: today ? 1.5 : 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: handleTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: doodle == null
                      ? Center(
                          child: AddDoodlePrompt(
                            language: language,
                            onTap: handleTap,
                          ),
                        )
                      : DoodlePreview(doodle: doodle!, padding: doodlePadding),
                ),
                Positioned(
                  left: 16,
                  top: 14,
                  child: Text(
                    '${date.day} ${monthNames(language)[date.month - 1]}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: today ? colors.primary : const Color(0xFF4F5751),
                      fontWeight: FontWeight.w800,
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
