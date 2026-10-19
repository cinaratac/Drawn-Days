import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import 'day_tap_callback.dart';
import 'doodle_painter.dart';
import 'sketch_paper.dart';

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
  late final PageController _controller;
  late int _visibleIndex;

  int _indexFor(DateTime date) => widget.today
      .difference(dateOnly(date))
      .inDays
      .clamp(0, _itemCount - 1)
      .toInt();

  DateTime _dateFor(int index) => widget.today.subtract(Duration(days: index));

  @override
  void initState() {
    super.initState();
    _visibleIndex = _indexFor(widget.focusDate);
    _controller = PageController(initialPage: _visibleIndex);
  }

  @override
  void didUpdateWidget(covariant DayFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focusChanged = !isSameDay(oldWidget.focusDate, widget.focusDate);
    final todayRequested = oldWidget.todayRequest != widget.todayRequest;
    if (!focusChanged && !todayRequested) return;
    final target = _indexFor(todayRequested ? widget.today : widget.focusDate);
    if (target == _visibleIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (!widget.isActive || (_visibleIndex - target).abs() > 7) {
        _controller.jumpToPage(target);
      } else {
        _controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _selectIndex(int index, {bool notify = true}) {
    final safeIndex = index.clamp(0, _itemCount - 1);
    if (_visibleIndex != safeIndex) setState(() => _visibleIndex = safeIndex);
    if (notify) widget.onVisibleDateChanged(_dateFor(safeIndex));
  }

  void _openIndex(int index) {
    final safeIndex = index.clamp(0, _itemCount - 1);
    _controller.animateToPage(
      safeIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dateFor(_visibleIndex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 1, 12, 76),
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: _DayStrip(
              selectedDate: selectedDate,
              today: widget.today,
              doodles: widget.doodles,
              onSelected: (date) => _openIndex(_indexFor(date)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              reverse: true,
              itemCount: _itemCount,
              onPageChanged: _selectIndex,
              itemBuilder: (context, index) {
                final date = _dateFor(index);
                return _FlowDayCard(
                  key: Key('day-${dateKey(date)}'),
                  date: date,
                  today: isSameDay(date, widget.today),
                  doodle: widget.doodles[dateKey(date)],
                  onTap: (rect) => widget.onDayTap(date, rect),
                  language: widget.language,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _SwipeHint(language: widget.language),
          const SizedBox(height: 7),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.selectedDate,
    required this.today,
    required this.doodles,
    required this.onSelected,
  });
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, Doodle> doodles;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final dates = List<DateTime>.generate(
      7,
      (index) => selectedDate.subtract(Duration(days: 6 - index)),
    );
    return Row(
      children: List.generate(dates.length, (index) {
        final date = dates[index];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == dates.length - 1 ? 0 : 5),
            child: _StripDay(
              date: date,
              selected: isSameDay(date, selectedDate),
              doodle: doodles[dateKey(date)],
              onTap: () => onSelected(date),
            ),
          ),
        );
      }),
    );
  }
}

class _StripDay extends StatelessWidget {
  const _StripDay({
    required this.date,
    required this.selected,
    required this.doodle,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final Doodle? doodle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: CustomPaint(
        painter: _StripCardPainter(
          empty: doodle == null,
          selected: selected,
          surface: context.drawnTheme.paper,
          ink: context.drawnTheme.ink,
          grid: context.drawnTheme.grid,
        ),
        child: Stack(
          children: [
            if (doodle != null)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
                  child: DoodlePreview(
                    doodle: doodle!,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            if (doodle == null && selected)
              Positioned(
                left: 7,
                right: 7,
                top: 22,
                bottom: 8,
                child: CustomPaint(
                  painter: _SmallFacePainter(color: context.drawnTheme.ink),
                ),
              ),
            Positioned(
              left: 8,
              top: 3,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: context.drawnTheme.ink,
                  fontFamily: 'PatrickHand',
                  fontSize: 17,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    const doodlePadding = EdgeInsets.fromLTRB(8, 45, 8, 10);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = math.min(
          constraints.maxHeight,
          constraints.maxWidth * .86,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: cardHeight,
            child: Builder(
              builder: (context) {
                void handleTap() {
                  final box = context.findRenderObject();
                  if (box is! RenderBox || !box.hasSize) return;
                  final rect = box.localToGlobal(Offset.zero) & box.size;
                  onTap(doodlePreviewPaintRect(rect, doodlePadding));
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StackedPaperPainter(
                          surface: context.drawnTheme.paper,
                          ink: context.drawnTheme.ink,
                          grid: context.drawnTheme.grid,
                          shadow: context.drawnTheme.shadow,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: handleTap,
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              if (doodle != null)
                                Positioned.fill(
                                  child: DoodlePreview(
                                    doodle: doodle!,
                                    padding: doodlePadding,
                                  ),
                                )
                              else
                                Positioned(
                                  left: 65,
                                  right: 65,
                                  top: 75,
                                  bottom: 55,
                                  child: CustomPaint(
                                    painter: _LargeFacePainter(
                                      color: context.drawnTheme.ink,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 23,
                                top: 18,
                                child: Text(
                                  '${date.day} ${monthNames(language)[date.month - 1]}',
                                  style: TextStyle(
                                    color: context.drawnTheme.mutedInk,
                                    fontFamily: 'PatrickHand',
                                    fontSize: 20,
                                    height: 1,
                                  ),
                                ),
                              ),
                              if (today)
                                const Positioned(
                                  right: 20,
                                  top: 12,
                                  child: _TodayBadge(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: -10,
                      child: Center(child: _PaperTape()),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.language});
  final AppLanguage language;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.arrow_back_rounded, color: Color(0xFF7D8780), size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            language == AppLanguage.english
                ? 'swipe to flip between days'
                : 'günler arasında kaydır',
            style: const TextStyle(
              color: Color(0xFF69756E),
              fontFamily: 'PatrickHand',
              fontSize: 16,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      const Icon(
        Icons.arrow_forward_rounded,
        color: Color(0xFFB8BCB4),
        size: 22,
      ),
    ],
  );
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _OvalPainter(),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Text(
        'today',
        style: TextStyle(
          color: Color(0xFF2E704F),
          fontFamily: 'PatrickHand',
          fontSize: 19,
          height: 1,
        ),
      ),
    ),
  );
}

class _PaperTape extends StatelessWidget {
  const _PaperTape();
  @override
  Widget build(BuildContext context) => const SketchTape(width: 94, height: 26);
}

class _StackedPaperPainter extends CustomPainter {
  const _StackedPaperPainter({
    required this.surface,
    required this.ink,
    required this.grid,
    required this.shadow,
  });
  final Color surface;
  final Color ink;
  final Color grid;
  final Color shadow;
  @override
  void paint(Canvas canvas, Size size) {
    final backPaint = Paint()
      ..color = grid.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(
      SketchPaperPath.create(size, offset: const Offset(-2, 10)),
      backPaint,
    );
    canvas.drawPath(
      SketchPaperPath.create(size, offset: const Offset(7, 5)),
      backPaint,
    );
    final front = SketchPaperPath.create(size);
    canvas.drawPath(
      SketchPaperPath.create(size, offset: const Offset(3, 4)),
      Paint()..color = shadow,
    );
    canvas.drawPath(front, Paint()..color = surface);
    canvas.drawPath(
      front,
      Paint()
        ..color = ink.withValues(alpha: .78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _StackedPaperPainter oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.ink != ink ||
      oldDelegate.grid != grid ||
      oldDelegate.shadow != shadow;
}

class _StripCardPainter extends CustomPainter {
  const _StripCardPainter({
    required this.empty,
    required this.selected,
    required this.surface,
    required this.ink,
    required this.grid,
  });
  final bool empty;
  final bool selected;
  final Color surface;
  final Color ink;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    final path = SketchPaperPath.create(size);
    if (!empty || selected) {
      canvas.drawPath(
        path,
        Paint()..color = selected ? const Color(0xFFF2D77A) : surface,
      );
    }
    final border = Paint()
      ..color = selected ? ink : grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.5 : 1.4;
    if (!empty || selected) {
      canvas.drawPath(path, border);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 4, metric.length)),
          border,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StripCardPainter oldDelegate) =>
      oldDelegate.empty != empty ||
      oldDelegate.selected != selected ||
      oldDelegate.surface != surface ||
      oldDelegate.ink != ink ||
      oldDelegate.grid != grid;
}

class _OvalPainter extends CustomPainter {
  const _OvalPainter();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawOval(
    Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
    Paint()
      ..color = const Color(0xFF2E704F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LargeFacePainter extends CustomPainter {
  const _LargeFacePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .08, size.height * .28)
        ..quadraticBezierTo(
          size.width * .23,
          size.height * .02,
          size.width * .4,
          size.height * .2,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .6, size.height * .18)
        ..quadraticBezierTo(
          size.width * .78,
          size.height * .04,
          size.width * .94,
          size.height * .26,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .25, size.height * .67)
        ..quadraticBezierTo(
          size.width * .51,
          size.height * .88,
          size.width * .78,
          size.height * .65,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LargeFacePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SmallFacePainter extends CustomPainter {
  const _SmallFacePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .18, size.height * .32),
      Offset(size.width * .38, size.height * .32),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .62, size.height * .32),
      Offset(size.width * .82, size.height * .32),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .25, size.height * .66)
        ..quadraticBezierTo(
          size.width * .5,
          size.height * .84,
          size.width * .76,
          size.height * .64,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SmallFacePainter oldDelegate) =>
      oldDelegate.color != color;
}
