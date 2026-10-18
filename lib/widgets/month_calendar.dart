import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import '../utils/doodle_eraser.dart';
import 'day_tap_callback.dart';
import 'doodle_painter.dart';

const _calendarHorizontalInset = 2.0;

enum MonthDoodleLayer { header, grid, canvas }

class MonthDrawingController {
  final GlobalKey headerKey = GlobalKey();
  final ValueNotifier<Doodle?> headerDoodle = ValueNotifier<Doodle?>(null);
  Object? _owner;
  void Function(PointerDownEvent)? _onDown;
  void Function(PointerMoveEvent)? _onMove;
  void Function(PointerEvent)? _onUp;
  VoidCallback? _onToggleMode;
  bool _disposed = false;
  bool drawingEnabled = false;

  bool get active => _owner != null;

  void attach(
    Object owner, {
    required void Function(PointerDownEvent) onDown,
    required void Function(PointerMoveEvent) onMove,
    required void Function(PointerEvent) onUp,
    required VoidCallback onToggleMode,
    required Doodle doodle,
    required bool enabled,
  }) {
    _owner = owner;
    _onDown = onDown;
    _onMove = onMove;
    _onUp = onUp;
    _onToggleMode = onToggleMode;
    drawingEnabled = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && identical(_owner, owner)) headerDoodle.value = doodle;
    });
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _onDown = null;
    _onMove = null;
    _onUp = null;
    _onToggleMode = null;
    drawingEnabled = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && _owner == null) headerDoodle.value = null;
    });
  }

  void updateHeader(Doodle doodle) {
    if (_owner != null) headerDoodle.value = doodle;
  }

  void updateDrawingEnabled(bool enabled) {
    drawingEnabled = enabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || drawingEnabled != enabled) return;
      final doodle = headerDoodle.value;
      if (doodle != null) headerDoodle.value = doodle.snapshot();
    });
  }

  void pointerDown(PointerDownEvent event) => _onDown?.call(event);
  void pointerMove(PointerMoveEvent event) => _onMove?.call(event);
  void pointerUp(PointerEvent event) => _onUp?.call(event);
  void toggleMode() => _onToggleMode?.call();

  void dispose() {
    _disposed = true;
    headerDoodle.dispose();
  }
}

typedef MonthDoodleChanged =
    void Function(DateTime month, MonthDoodleLayer layer, Doodle doodle);

int _rowCountForMonth(DateTime month, {required bool mondayFirst}) {
  final firstDay = DateTime(month.year, month.month);
  final leadingEmptyCells = mondayFirst
      ? firstDay.weekday - DateTime.monday
      : firstDay.weekday % 7;
  return ((leadingEmptyCells + daysInMonth(month)) / 7).ceil();
}

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
    required this.monthGridDoodles,
    required this.monthHeaderDoodles,
    required this.monthCanvasDoodles,
    required this.drawingController,
    required this.onMonthDoodleChanged,
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
  final Map<String, Doodle> monthGridDoodles;
  final Map<String, Doodle> monthHeaderDoodles;
  final Map<String, Doodle> monthCanvasDoodles;
  final MonthDrawingController drawingController;
  final MonthDoodleChanged onMonthDoodleChanged;
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
  static const _gridControlExtent = 24.0;
  static const _drawingPanelExtent = 292.0;
  static const _pastMonthCount = 1200;
  static const _futureMonthCount = 1200;
  static const _monthCount = _pastMonthCount + 1 + _futureMonthCount;
  static const _currentMonthIndex = _pastMonthCount;

  final ScrollController _scrollController = ScrollController();
  List<double> _itemExtents = const [];
  List<double> _itemOffsets = const [];
  double _cellSize = 0;
  bool? _metricsMondayFirst;
  double _viewportHeight = 0;
  int _visibleMonthIndex = 0;
  bool _initialPositionApplied = false;
  int? _expandedMonthIndex;
  bool _drawingEnabled = true;

  void _rebuildMetrics() {
    if (_cellSize <= 0) return;
    final extents = List<double>.filled(_monthCount, 0);
    final offsets = List<double>.filled(_monthCount + 1, 0);
    for (var index = 0; index < _monthCount; index++) {
      final month = _monthFor(index);
      final rowCount = _rowCountForMonth(
        month,
        mondayFirst: widget.mondayFirst,
      );
      extents[index] =
          _monthHeaderExtent +
          (_cellSize * rowCount) +
          _gridControlExtent +
          (_expandedMonthIndex == index ? _drawingPanelExtent : 0) +
          _nextMonthHeaderExtent;
      offsets[index + 1] = offsets[index] + extents[index];
    }
    _itemExtents = extents;
    _itemOffsets = offsets;
  }

  void _toggleMonthDrawing(int index) {
    final monthTopBefore = _itemOffsets[index];
    setState(() {
      final closing = _expandedMonthIndex == index;
      _expandedMonthIndex = closing ? null : index;
      _rebuildMetrics();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final delta = _itemOffsets[index] - monthTopBefore;
      if (delta.abs() > .5) {
        _scrollController.jumpTo(
          (_scrollController.offset + delta).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

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
      if (!mounted || !_scrollController.hasClients || _itemExtents.isEmpty) {
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
    var low = 0;
    var high = _monthCount;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_itemOffsets[middle + 1] <= referenceOffset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low.clamp(0, _monthCount - 1);
  }

  double _offsetFor(int index, {bool alignAtBottom = false}) {
    final itemExtent = _itemExtents[index];
    final bottomAlignment = alignAtBottom
        ? (_viewportHeight - _navigationClearance - itemExtent).clamp(
            0.0,
            double.infinity,
          )
        : 0.0;
    return (_itemOffsets[index] - bottomAlignment)
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
    final cellCenterOffset =
        _gridTopOffset + (rowIndex * _cellSize) + (_cellSize / 2);
    return (_itemOffsets[monthIndex] + cellCenterOffset - (_viewportHeight / 2))
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
  }

  void _handleScroll() {
    if (_itemExtents.isEmpty || !_scrollController.hasClients) return;
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
        final metricsChanged =
            _itemExtents.isEmpty ||
            _cellSize != cellSize ||
            _metricsMondayFirst != widget.mondayFirst;
        if (metricsChanged) {
          _cellSize = cellSize;
          _metricsMondayFirst = widget.mondayFirst;
          _rebuildMetrics();
          if (_initialPositionApplied) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_scrollController.hasClients) return;
              _scrollController.jumpTo(_offsetFor(_indexFor(widget.month)));
            });
          }
        }
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
            physics: _expandedMonthIndex == null || !_drawingEnabled
                ? null
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: _navigationClearance),
            itemCount: _monthCount,
            itemExtentBuilder: (index, dimensions) => _itemExtents[index],
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            scrollCacheExtent: ScrollCacheExtent.pixels(cellSize * 9),
            itemBuilder: (context, index) {
              final month = _monthFor(index);
              return RepaintBoundary(
                child: _MonthPage(
                  key: ValueKey('month-${month.year}-${month.month}'),
                  month: month,
                  today: widget.today,
                  doodles: widget.doodles,
                  gridDoodle: widget.monthGridDoodles[dateKey(month)],
                  headerDoodle: widget.monthHeaderDoodles[dateKey(month)],
                  canvasDoodle: widget.monthCanvasDoodles[dateKey(month)],
                  drawingController: widget.drawingController,
                  expanded: _expandedMonthIndex == index,
                  drawingEnabled:
                      _expandedMonthIndex == index && _drawingEnabled,
                  onDrawingEnabledChanged: (enabled) {
                    if (_expandedMonthIndex != index) return;
                    setState(() => _drawingEnabled = enabled);
                  },
                  onToggleExpanded: () => _toggleMonthDrawing(index),
                  onMonthDoodleChanged: widget.onMonthDoodleChanged,
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

class _MonthPage extends StatefulWidget {
  const _MonthPage({
    super.key,
    required this.month,
    required this.today,
    required this.doodles,
    required this.gridDoodle,
    required this.headerDoodle,
    required this.canvasDoodle,
    required this.drawingController,
    required this.expanded,
    required this.drawingEnabled,
    required this.onDrawingEnabledChanged,
    required this.onToggleExpanded,
    required this.onMonthDoodleChanged,
    required this.onDayTap,
    required this.language,
    required this.mondayFirst,
  });

  final DateTime month;
  final DateTime today;
  final Map<String, Doodle> doodles;
  final Doodle? gridDoodle;
  final Doodle? headerDoodle;
  final Doodle? canvasDoodle;
  final MonthDrawingController drawingController;
  final bool expanded;
  final bool drawingEnabled;
  final ValueChanged<bool> onDrawingEnabledChanged;
  final VoidCallback onToggleExpanded;
  final MonthDoodleChanged onMonthDoodleChanged;
  final DayTapCallback onDayTap;
  final AppLanguage language;
  final bool mondayFirst;

  @override
  State<_MonthPage> createState() => _MonthPageState();
}

class _MonthPageState extends State<_MonthPage> {
  static const _palette = <Color>[
    Color(0xFF292621),
    Color(0xFF315F46),
    Color(0xFFF0B84B),
    Color(0xFF4D83A8),
    Color(0xFF8A70A8),
    Color(0xFFA65E35),
    Color(0xFFE06C9F),
    Color(0xFFE77B66),
    Color(0xFFC94B45),
    Color(0xFF3B9A92),
    Color(0xFFF28C45),
  ];

  late List<DoodleStroke> _gridStrokes;
  late List<DoodleStroke> _headerStrokes;
  late List<DoodleStroke> _canvasStrokes;
  final GlobalKey _gridDrawingKey = GlobalKey();
  final GlobalKey _canvasDrawingKey = GlobalKey();
  Color _selectedColor = _palette.first;
  double _selectedWidth = 6.5;
  bool _eraserEnabled = false;
  MonthDoodleLayer? _pointerLayer;
  Offset? _lastPointerGlobal;
  final Set<MonthDoodleLayer> _changedLayers = <MonthDoodleLayer>{};
  final List<List<MonthDoodleLayer>> _strokeHistory =
      <List<MonthDoodleLayer>>[];
  final List<MonthDoodleLayer> _activeGestureStrokes = <MonthDoodleLayer>[];

  @override
  void initState() {
    super.initState();
    _gridStrokes = _copyStrokes(widget.gridDoodle);
    _headerStrokes = _copyStrokes(widget.headerDoodle);
    _canvasStrokes = _copyStrokes(widget.canvasDoodle);
    if (widget.expanded) _attachController();
  }

  @override
  void didUpdateWidget(covariant _MonthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDoodle(widget.gridDoodle, oldWidget.gridDoodle)) {
      _gridStrokes = _copyStrokes(widget.gridDoodle);
    }
    if (!_sameDoodle(widget.headerDoodle, oldWidget.headerDoodle)) {
      _headerStrokes = _copyStrokes(widget.headerDoodle);
    }
    if (!_sameDoodle(widget.canvasDoodle, oldWidget.canvasDoodle)) {
      _canvasStrokes = _copyStrokes(widget.canvasDoodle);
    }
    if (!oldWidget.expanded && widget.expanded) _attachController();
    if (oldWidget.drawingEnabled != widget.drawingEnabled) {
      widget.drawingController.updateDrawingEnabled(widget.drawingEnabled);
    }
    if (oldWidget.expanded && !widget.expanded) {
      widget.drawingController.detach(this);
    }
  }

  void _attachController() {
    widget.drawingController.attach(
      this,
      onDown: _handlePointerDown,
      onMove: _handlePointerMove,
      onUp: _handlePointerUp,
      onToggleMode: () =>
          widget.onDrawingEnabledChanged(!widget.drawingEnabled),
      doodle: Doodle(strokes: _headerStrokes),
      enabled: widget.drawingEnabled,
    );
  }

  @override
  void dispose() {
    widget.drawingController.detach(this);
    super.dispose();
  }

  bool _sameDoodle(Doodle? first, Doodle? second) =>
      (first ?? const Doodle(strokes: <DoodleStroke>[])).hasSameContent(second);

  List<DoodleStroke> _copyStrokes(Doodle? doodle) =>
      doodle?.strokes
          .map((stroke) => stroke.copyWith(points: List.of(stroke.points)))
          .toList() ??
      <DoodleStroke>[];

  List<DoodleStroke> _strokesFor(MonthDoodleLayer layer) => switch (layer) {
    MonthDoodleLayer.header => _headerStrokes,
    MonthDoodleLayer.grid => _gridStrokes,
    MonthDoodleLayer.canvas => _canvasStrokes,
  };

  void _replaceStrokesFor(MonthDoodleLayer layer, List<DoodleStroke> strokes) {
    switch (layer) {
      case MonthDoodleLayer.header:
        _headerStrokes = strokes;
      case MonthDoodleLayer.grid:
        _gridStrokes = strokes;
      case MonthDoodleLayer.canvas:
        _canvasStrokes = strokes;
    }
  }

  RenderBox? _drawingBox(MonthDoodleLayer layer) {
    final key = switch (layer) {
      MonthDoodleLayer.header => widget.drawingController.headerKey,
      MonthDoodleLayer.grid => _gridDrawingKey,
      MonthDoodleLayer.canvas => _canvasDrawingKey,
    };
    final renderObject = key.currentContext?.findRenderObject();
    return renderObject is RenderBox && renderObject.hasSize
        ? renderObject
        : null;
  }

  Offset? _normalizedIn(MonthDoodleLayer layer, Offset globalPosition) {
    final box = _drawingBox(layer);
    if (box == null) return null;
    final local = box.globalToLocal(globalPosition);
    return Offset(
      (local.dx / box.size.width).clamp(0, 1),
      (local.dy / box.size.height).clamp(0, 1),
    );
  }

  (MonthDoodleLayer, Offset)? _drawingPoint(Offset globalPosition) {
    for (final (layer, key) in <(MonthDoodleLayer, GlobalKey)>[
      (MonthDoodleLayer.header, widget.drawingController.headerKey),
      (MonthDoodleLayer.grid, _gridDrawingKey),
      (MonthDoodleLayer.canvas, _canvasDrawingKey),
    ]) {
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final local = renderObject.globalToLocal(globalPosition);
      if (local.dx < 0 ||
          local.dy < 0 ||
          local.dx > renderObject.size.width ||
          local.dy > renderObject.size.height) {
        continue;
      }
      if (layer == MonthDoodleLayer.grid &&
          local.dx > renderObject.size.width - 40 &&
          local.dy > renderObject.size.height - 40) {
        return null;
      }
      return (
        layer,
        Offset(
          (local.dx / renderObject.size.width).clamp(0, 1),
          (local.dy / renderObject.size.height).clamp(0, 1),
        ),
      );
    }
    return null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.expanded || !widget.drawingEnabled) return;
    final hit = _drawingPoint(event.position);
    if (hit == null) return;
    _changedLayers.clear();
    _activeGestureStrokes.clear();
    _lastPointerGlobal = event.position;
    if (_eraserEnabled) {
      _pointerLayer = hit.$1;
      _strokeHistory.clear();
      _eraseAt(hit.$1, hit.$2, hit.$2);
      return;
    }
    _beginStrokeAt(hit.$1, hit.$2);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!widget.expanded || !widget.drawingEnabled || _pointerLayer == null) {
      return;
    }
    final hit = _drawingPoint(event.position);
    if (hit == null) return;
    if (_eraserEnabled) {
      final previousPoint = _lastPointerGlobal == null
          ? hit.$2
          : (_normalizedIn(hit.$1, _lastPointerGlobal!) ?? hit.$2);
      _pointerLayer = hit.$1;
      _eraseAt(hit.$1, previousPoint, hit.$2);
      _lastPointerGlobal = event.position;
      return;
    }
    if (hit.$1 != _pointerLayer) {
      final previousLayer = _pointerLayer!;
      final previousGlobal = _lastPointerGlobal ?? event.position;
      final previousBox = _drawingBox(previousLayer);
      final nextBox = _drawingBox(hit.$1);
      if (previousBox != null && nextBox != null) {
        final previousRect =
            previousBox.localToGlobal(Offset.zero) & previousBox.size;
        final nextRect = nextBox.localToGlobal(Offset.zero) & nextBox.size;
        final movingDown = event.position.dy >= previousGlobal.dy;
        final oldBoundaryY = movingDown
            ? previousRect.bottom
            : previousRect.top;
        final newBoundaryY = movingDown ? nextRect.top : nextRect.bottom;
        final deltaY = event.position.dy - previousGlobal.dy;
        final interpolation = deltaY.abs() < .001
            ? .5
            : ((oldBoundaryY - previousGlobal.dy) / deltaY).clamp(0.0, 1.0);
        final boundaryX =
            previousGlobal.dx +
            ((event.position.dx - previousGlobal.dx) * interpolation);
        final oldBoundary = _normalizedIn(
          previousLayer,
          Offset(boundaryX, oldBoundaryY),
        );
        final newBoundary = _normalizedIn(
          hit.$1,
          Offset(boundaryX, newBoundaryY),
        );
        if (oldBoundary != null) _appendPoint(previousLayer, oldBoundary);
        _beginStrokeAt(hit.$1, newBoundary ?? hit.$2);
        _appendPoint(hit.$1, hit.$2);
      } else {
        _beginStrokeAt(hit.$1, hit.$2);
      }
      _lastPointerGlobal = event.position;
      return;
    }
    _appendPoint(hit.$1, hit.$2);
    _lastPointerGlobal = event.position;
  }

  void _handlePointerUp(PointerEvent event) {
    if (_pointerLayer == null) return;
    for (final layer in _changedLayers) {
      _saveLayer(layer);
    }
    if (_activeGestureStrokes.isNotEmpty) {
      _strokeHistory.add(List<MonthDoodleLayer>.from(_activeGestureStrokes));
    }
    _changedLayers.clear();
    _activeGestureStrokes.clear();
    _pointerLayer = null;
    _lastPointerGlobal = null;
  }

  void _beginStrokeAt(MonthDoodleLayer layer, Offset point) {
    setState(() {
      _pointerLayer = layer;
      _changedLayers.add(layer);
      _activeGestureStrokes.add(layer);
      _strokesFor(layer).add(
        DoodleStroke(
          points: <Offset>[point],
          colorValue: _selectedColor.toARGB32(),
          width: _selectedWidth,
        ),
      );
    });
    if (layer == MonthDoodleLayer.header) _publishHeader();
  }

  void _appendPoint(MonthDoodleLayer layer, Offset point) {
    final strokes = _strokesFor(layer);
    if (strokes.isEmpty ||
        (strokes.last.points.last - point).distanceSquared < .000004) {
      return;
    }
    setState(() => strokes.last.points.add(point));
    if (layer == MonthDoodleLayer.header) _publishHeader();
  }

  void _eraseAt(MonthDoodleLayer layer, Offset from, Offset to) {
    final current = _strokesFor(layer);
    final box = _drawingBox(layer);
    if (box == null) return;
    final erased = eraseDoodleAlong(
      current,
      from: from,
      to: to,
      canvasSize: box.size,
      eraserWidth: _selectedWidth,
    );
    if (Doodle(strokes: erased).hasSameContent(Doodle(strokes: current))) {
      return;
    }
    setState(() {
      _replaceStrokesFor(layer, erased);
      _changedLayers.add(layer);
    });
    if (layer == MonthDoodleLayer.header) _publishHeader();
  }

  void _publishHeader() => widget.drawingController.updateHeader(
    Doodle(strokes: List<DoodleStroke>.unmodifiable(_headerStrokes)),
  );

  void _saveLayer(MonthDoodleLayer layer) {
    widget.onMonthDoodleChanged(
      widget.month,
      layer,
      Doodle(strokes: List.unmodifiable(_strokesFor(layer))).snapshot(),
    );
  }

  void _undo() {
    final affected = <MonthDoodleLayer>{};
    setState(() {
      if (_strokeHistory.isNotEmpty) {
        final gesture = _strokeHistory.removeLast();
        for (final layer in gesture.reversed) {
          final strokes = _strokesFor(layer);
          if (strokes.isNotEmpty) strokes.removeLast();
          affected.add(layer);
        }
      } else if (_canvasStrokes.isNotEmpty) {
        _canvasStrokes.removeLast();
        affected.add(MonthDoodleLayer.canvas);
      } else if (_gridStrokes.isNotEmpty) {
        _gridStrokes.removeLast();
        affected.add(MonthDoodleLayer.grid);
      } else if (_headerStrokes.isNotEmpty) {
        _headerStrokes.removeLast();
        affected.add(MonthDoodleLayer.header);
      }
    });
    if (affected.contains(MonthDoodleLayer.header)) _publishHeader();
    for (final layer in affected) {
      _saveLayer(layer);
    }
  }

  void _clear() {
    if (_headerStrokes.isEmpty &&
        _gridStrokes.isEmpty &&
        _canvasStrokes.isEmpty) {
      return;
    }
    setState(() {
      _headerStrokes.clear();
      _gridStrokes.clear();
      _canvasStrokes.clear();
      _strokeHistory.clear();
    });
    _publishHeader();
    _saveLayer(MonthDoodleLayer.header);
    _saveLayer(MonthDoodleLayer.grid);
    _saveLayer(MonthDoodleLayer.canvas);
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(widget.month.year, widget.month.month);
    final leadingEmptyCells = widget.mondayFirst
        ? firstDay.weekday - DateTime.monday
        : firstDay.weekday % 7;
    final dayCount = daysInMonth(widget.month);
    final rowCount = _rowCountForMonth(
      widget.month,
      mondayFirst: widget.mondayFirst,
    );
    final weekdayHeader = SizedBox(
      height: _MonthCalendarState._monthHeaderExtent,
      child: Row(
        children:
            weekdayNamesShort(widget.language, mondayFirst: widget.mondayFirst)
                .map(
                  (weekday) => Expanded(
                    child: Center(
                      child: Text(
                        weekday.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.drawnTheme.mutedInk,
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
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _calendarHorizontalInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = constraints.maxWidth / 7;
                final gridHeight = cellSize * rowCount;
                const headerHeight = _MonthCalendarState._monthHeaderExtent;

                return SizedBox(
                  height:
                      headerHeight +
                      gridHeight +
                      _MonthCalendarState._gridControlExtent,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height: headerHeight,
                        child: weekdayHeader,
                      ),
                      Positioned(
                        left: 0,
                        top: headerHeight,
                        right: 0,
                        height: gridHeight,
                        child: CustomPaint(
                          painter: _CalendarGridPainter(
                            rowCount: rowCount,
                            color: context.drawnTheme.grid,
                          ),
                          child: Column(
                            children: List<Widget>.generate(rowCount, (row) {
                              return SizedBox(
                                height: cellSize,
                                child: Row(
                                  children: List<Widget>.generate(7, (column) {
                                    final index = (row * 7) + column;
                                    final dayNumber =
                                        index - leadingEmptyCells + 1;
                                    if (dayNumber < 1 || dayNumber > dayCount) {
                                      return const Expanded(
                                        child: SizedBox.expand(),
                                      );
                                    }

                                    final date = DateTime(
                                      widget.month.year,
                                      widget.month.month,
                                      dayNumber,
                                    );
                                    final future = isAfterDay(
                                      date,
                                      widget.today,
                                    );
                                    final key = dateKey(date);

                                    return Expanded(
                                      child: _MonthDayCell(
                                        key: Key('day-$key'),
                                        date: date,
                                        today: isSameDay(date, widget.today),
                                        row: row,
                                        column: column,
                                        future: future,
                                        doodle: widget.doodles[key],
                                        onTap: (targetRect) {
                                          if (future) {
                                            final message =
                                                widget.language ==
                                                    AppLanguage.english
                                                ? "This day hasn't happened yet."
                                                : 'Bu gün henüz yaşanmadı.';
                                            ScaffoldMessenger.of(context)
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                SnackBar(
                                                  content: Text(message),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            return;
                                          }
                                          widget.onDayTap(date, targetRect);
                                        },
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height:
                            headerHeight +
                            gridHeight +
                            _MonthCalendarState._gridControlExtent,
                        child: IgnorePointer(
                          ignoring: !widget.drawingEnabled,
                          child: AbsorbPointer(
                            absorbing: widget.expanded,
                            child: KeyedSubtree(
                              key: _gridDrawingKey,
                              child: CustomPaint(
                                key: const Key('month-grid-drawing-surface'),
                                painter: DoodlePainter(
                                  doodle: Doodle(strokes: _gridStrokes),
                                  fitSquare: false,
                                  cacheGeometry: false,
                                  darkInkReplacement:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? context.drawnTheme.ink
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 7,
                        bottom: 0,
                        child: _MonthDrawingToggle(
                          expanded: widget.expanded,
                          onTap: widget.onToggleExpanded,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (widget.expanded)
              _MonthDrawingPanel(
                strokes: _canvasStrokes,
                selectedColor: _selectedColor,
                selectedWidth: _selectedWidth,
                eraserEnabled: _eraserEnabled,
                onColorSelected: (color) => setState(() {
                  _selectedColor = color;
                  _eraserEnabled = false;
                }),
                onWidthSelected: (width) => setState(() {
                  _selectedWidth = width;
                }),
                onEraserSelected: () =>
                    setState(() => _eraserEnabled = !_eraserEnabled),
                canvasKey: _canvasDrawingKey,
                onUndo: _undo,
                onClear: _clear,
                palette: _palette,
              ),
            _NextMonthHeading(
              month: DateTime(widget.month.year, widget.month.month + 1),
              language: widget.language,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthDrawingToggle extends StatelessWidget {
  const _MonthDrawingToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return Semantics(
      button: true,
      label: expanded ? 'Ay çizimini kapat' : 'Ay çizimini aç',
      child: GestureDetector(
        key: const Key('month-drawing-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 32,
          child: CustomPaint(
            painter: _HandDrawnArrowButtonPainter(
              fill: theme.selection,
              ink: theme.ink,
              expanded: expanded,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDrawingPanel extends StatelessWidget {
  const _MonthDrawingPanel({
    required this.strokes,
    required this.selectedColor,
    required this.selectedWidth,
    required this.eraserEnabled,
    required this.onColorSelected,
    required this.onWidthSelected,
    required this.onEraserSelected,
    required this.canvasKey,
    required this.onUndo,
    required this.onClear,
    required this.palette,
  });

  final List<DoodleStroke> strokes;
  final Color selectedColor;
  final double selectedWidth;
  final bool eraserEnabled;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onWidthSelected;
  final VoidCallback onEraserSelected;
  final GlobalKey canvasKey;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return SizedBox(
      key: const Key('month-drawing-panel'),
      height: _MonthCalendarState._drawingPanelExtent,
      child: Column(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: canvasKey,
              child: CustomPaint(
                key: const Key('month-drawing-canvas'),
                painter: DoodlePainter(
                  doodle: Doodle(strokes: strokes),
                  fitSquare: false,
                  cacheGeometry: false,
                  darkInkReplacement:
                      Theme.of(context).brightness == Brightness.dark
                      ? theme.ink
                      : null,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: palette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 13),
              itemBuilder: (context, index) {
                final color = palette[index];
                return Center(
                  child: GestureDetector(
                    key: Key('month-color-$index'),
                    onTap: () => onColorSelected(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: selectedColor == color && !eraserEnabled ? 30 : 24,
                      height: selectedColor == color && !eraserEnabled
                          ? 30
                          : 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color && !eraserEnabled
                            ? Border.all(color: theme.ink, width: 2)
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Row(
              children: [
                Text(
                  'Fırça',
                  style: TextStyle(
                    color: theme.mutedInk,
                    fontFamily: 'PatrickHand',
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 8),
                for (final width in const <double>[3.5, 6.5, 10.5])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      key: Key('month-brush-${width.toStringAsFixed(1)}'),
                      onTap: () => onWidthSelected(width),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 38,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selectedWidth == width
                              ? theme.selection.withValues(alpha: .72)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Container(
                            width: 24,
                            height: width.clamp(2.5, 8),
                            decoration: BoxDecoration(
                              color: theme.ink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                _SketchToolButton(
                  buttonKey: const Key('month-drawing-eraser'),
                  tooltip: 'Silgi',
                  onTap: onEraserSelected,
                  backgroundColor: eraserEnabled
                      ? theme.selection.withValues(alpha: .78)
                      : null,
                  painter: _SketchEraserPainter(color: theme.ink),
                ),
                const Spacer(),
                _SketchToolButton(
                  buttonKey: const Key('month-drawing-undo'),
                  tooltip: 'Son çizgiyi geri al',
                  onTap: onUndo,
                  painter: _SketchUndoPainter(color: theme.ink),
                ),
                const SizedBox(width: 3),
                _SketchToolButton(
                  buttonKey: const Key('month-drawing-clear'),
                  tooltip: 'Aylık çizimi temizle',
                  onTap: onClear,
                  painter: const _SketchTrashPainter(color: Color(0xFFB64F45)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandDrawnArrowButtonPainter extends CustomPainter {
  const _HandDrawnArrowButtonPainter({
    required this.fill,
    required this.ink,
    required this.expanded,
  });

  final Color fill;
  final Color ink;
  final bool expanded;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..moveTo(size.width * .52, 2)
      ..cubicTo(
        size.width * .82,
        1,
        size.width - 1,
        size.height * .25,
        size.width - 2,
        size.height * .53,
      )
      ..cubicTo(
        size.width - 3,
        size.height * .84,
        size.width * .72,
        size.height - 1,
        size.width * .46,
        size.height - 2,
      )
      ..cubicTo(
        size.width * .16,
        size.height - 1,
        1,
        size.height * .73,
        2,
        size.height * .45,
      )
      ..cubicTo(3, size.height * .15, size.width * .23, 2, size.width * .52, 2)
      ..close();
    canvas
      ..drawPath(outline, Paint()..color = fill.withValues(alpha: .92))
      ..drawPath(
        outline,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    canvas.save();
    if (expanded) {
      canvas
        ..translate(size.width, size.height)
        ..rotate(math.pi);
    }
    final arrow = Path()
      ..moveTo(size.width * .29, size.height * .39)
      ..quadraticBezierTo(
        size.width * .49,
        size.height * .60,
        size.width * .52,
        size.height * .66,
      )
      ..quadraticBezierTo(
        size.width * .58,
        size.height * .57,
        size.width * .73,
        size.height * .38,
      );
    canvas.drawPath(
      arrow,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandDrawnArrowButtonPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.ink != ink ||
      oldDelegate.expanded != expanded;
}

class _SketchToolButton extends StatelessWidget {
  const _SketchToolButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onTap,
    required this.painter,
    this.backgroundColor,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onTap;
  final CustomPainter painter;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: CustomPaint(painter: painter),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchEraserPainter extends CustomPainter {
  const _SketchEraserPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .24, size.height * .62)
      ..lineTo(size.width * .52, size.height * .29)
      ..quadraticBezierTo(
        size.width * .59,
        size.height * .22,
        size.width * .67,
        size.height * .29,
      )
      ..lineTo(size.width * .77, size.height * .39)
      ..quadraticBezierTo(
        size.width * .83,
        size.height * .46,
        size.width * .76,
        size.height * .54,
      )
      ..lineTo(size.width * .56, size.height * .75)
      ..lineTo(size.width * .35, size.height * .75)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .46, size.height * .38),
      Offset(size.width * .67, size.height * .58),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .34, size.height * .77),
      Offset(size.width * .74, size.height * .77),
      paint..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _SketchEraserPainter oldDelegate) =>
      oldDelegate.color != color;
}

class MonthDrawingModeButton extends StatelessWidget {
  const MonthDrawingModeButton({
    super.key,
    required this.drawingEnabled,
    required this.onTap,
  });

  final bool drawingEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    final label = drawingEnabled ? 'Kaydırma moduna geç' : 'Çizim moduna geç';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: const Key('month-drawing-mode'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 38,
            height: 34,
            decoration: BoxDecoration(
              color: theme.selection.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _SketchModePainter(
                color: theme.ink,
                showHand: !drawingEnabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchModePainter extends CustomPainter {
  const _SketchModePainter({required this.color, required this.showHand});

  final Color color;
  final bool showHand;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (!showHand) {
      canvas.drawPath(
        Path()
          ..moveTo(10, 25)
          ..lineTo(12, 20)
          ..lineTo(25, 7)
          ..quadraticBezierTo(27, 6, 29, 8)
          ..quadraticBezierTo(30, 10, 28, 12)
          ..lineTo(15, 25)
          ..close()
          ..moveTo(23, 9)
          ..lineTo(27, 13),
        paint,
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(11, 18)
        ..lineTo(11, 11)
        ..quadraticBezierTo(12, 8, 14, 10)
        ..lineTo(14, 16)
        ..lineTo(14, 7)
        ..quadraticBezierTo(16, 4, 18, 7)
        ..lineTo(18, 15)
        ..lineTo(18, 7)
        ..quadraticBezierTo(20, 5, 22, 8)
        ..lineTo(22, 16)
        ..lineTo(22, 10)
        ..quadraticBezierTo(24, 8, 26, 11)
        ..lineTo(26, 21)
        ..quadraticBezierTo(24, 28, 18, 28)
        ..quadraticBezierTo(13, 27, 10, 22)
        ..lineTo(8, 19)
        ..quadraticBezierTo(8, 16, 11, 18),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SketchModePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.showHand != showHand;
}

class _SketchUndoPainter extends CustomPainter {
  const _SketchUndoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .29, size.height * .37)
      ..cubicTo(
        size.width * .48,
        size.height * .19,
        size.width * .79,
        size.height * .29,
        size.width * .77,
        size.height * .53,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .72,
        size.width * .55,
        size.height * .78,
        size.width * .40,
        size.height * .70,
      );
    final head = Path()
      ..moveTo(size.width * .30, size.height * .37)
      ..quadraticBezierTo(
        size.width * .38,
        size.height * .38,
        size.width * .45,
        size.height * .42,
      )
      ..moveTo(size.width * .30, size.height * .37)
      ..quadraticBezierTo(
        size.width * .31,
        size.height * .29,
        size.width * .34,
        size.height * .23,
      );
    canvas
      ..drawPath(path, paint)
      ..drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant _SketchUndoPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SketchTrashPainter extends CustomPainter {
  const _SketchTrashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(size.width * .32, size.height * .34)
          ..quadraticBezierTo(
            size.width * .50,
            size.height * .32,
            size.width * .70,
            size.height * .35,
          ),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width * .40, size.height * .29)
          ..quadraticBezierTo(
            size.width * .49,
            size.height * .24,
            size.width * .59,
            size.height * .29,
          ),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width * .36, size.height * .39)
          ..lineTo(size.width * .40, size.height * .76)
          ..quadraticBezierTo(
            size.width * .51,
            size.height * .80,
            size.width * .64,
            size.height * .75,
          )
          ..lineTo(size.width * .68, size.height * .39),
        paint,
      )
      ..drawLine(
        Offset(size.width * .48, size.height * .44),
        Offset(size.width * .49, size.height * .69),
        paint,
      )
      ..drawLine(
        Offset(size.width * .58, size.height * .44),
        Offset(size.width * .57, size.height * .69),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _SketchTrashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CalendarGridPainter extends CustomPainter {
  const _CalendarGridPainter({required this.rowCount, required this.color});

  final int rowCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
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
    for (var row = 0; row <= rowCount; row++) {
      final y = (size.height / rowCount) * row;
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
  bool shouldRepaint(covariant _CalendarGridPainter oldDelegate) =>
      oldDelegate.rowCount != rowCount || oldDelegate.color != color;
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
                    style: TextStyle(
                      color: context.drawnTheme.ink,
                      fontFamily: 'PatrickHand',
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${month.year}',
                    style: TextStyle(
                      color: context.drawnTheme.mutedInk,
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
    final drawnTheme = context.drawnTheme;

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
                          ? drawnTheme.mutedInk.withValues(alpha: .5)
                          : today
                          ? colors.primary
                          : drawnTheme.ink,
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
    for (final (index, headDirection) in const <double>[-0.62, 0.62].indexed) {
      final end =
          target -
          Offset(
            math.cos(angle + headDirection) * arrowHeadLength,
            math.sin(angle + headDirection) * arrowHeadLength,
          );
      final headMidpoint = Offset.lerp(target, end, 0.52)!;
      final headVector = end - target;
      final headNormal =
          Offset(-headVector.dy, headVector.dx) / headVector.distance;
      final unevenBend = index == 0 ? 2.3 : -1.7;
      canvas.drawPath(
        Path()
          ..moveTo(target.dx, target.dy)
          ..quadraticBezierTo(
            headMidpoint.dx + (headNormal.dx * unevenBend),
            headMidpoint.dy + (headNormal.dy * unevenBend),
            end.dx,
            end.dy,
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
      tail.dx - (textPainter.width / 2),
      tailBelow ? tail.dy + 5 : tail.dy - textPainter.height - 5,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _YouAreHerePainter oldDelegate) =>
      oldDelegate.row != row || oldDelegate.column != column;
}
