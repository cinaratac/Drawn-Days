import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../l10n/app_strings.dart';
import '../services/doodle_gallery_service.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import '../utils/doodle_eraser.dart';
import 'doodle_painter.dart';
import 'hand_drawn_heart.dart';
import 'sketch_paper.dart';

typedef DoodleDownloadCallback =
    Future<void> Function(DateTime date, Doodle doodle);

Future<DoodleEditorResult?> showDoodleEditor({
  required BuildContext context,
  required DateTime date,
  Doodle? initialDoodle,
  bool initialFavorite = false,
  Future<bool> Function(Doodle doodle, bool isFavorite)? onFavoriteChanged,
  DoodleDownloadCallback? onDownload,
  bool hapticsEnabled = true,
  AppLanguage language = AppLanguage.english,
}) {
  return Navigator.of(context).push<DoodleEditorResult>(
    PageRouteBuilder<DoodleEditorResult>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => DoodleEditorPage(
        date: date,
        initialDoodle: initialDoodle,
        initialFavorite: initialFavorite,
        onFavoriteChanged: onFavoriteChanged,
        onDownload: onDownload,
        hapticsEnabled: hapticsEnabled,
        language: language,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}

class DoodleEditorResult {
  const DoodleEditorResult({
    required this.doodle,
    required this.sourceRect,
    required this.isFavorite,
  });

  final Doodle doodle;
  final Rect? sourceRect;
  final bool isFavorite;
}

class DoodleEditorPage extends StatefulWidget {
  const DoodleEditorPage({
    super.key,
    required this.date,
    required this.hapticsEnabled,
    required this.language,
    required this.initialFavorite,
    this.onFavoriteChanged,
    this.onDownload,
    this.initialDoodle,
  });

  final DateTime date;
  final bool hapticsEnabled;
  final AppLanguage language;
  final Doodle? initialDoodle;
  final bool initialFavorite;
  final Future<bool> Function(Doodle doodle, bool isFavorite)?
  onFavoriteChanged;
  final DoodleDownloadCallback? onDownload;

  @override
  State<DoodleEditorPage> createState() => _DoodleEditorPageState();
}

class _DoodleEditorPageState extends State<DoodleEditorPage> {
  static const _palette = <Color>[
    Color(0xFF292621),
    Color(0xFF315F46),
    Color(0xFFF0B84B),
    Color(0xFF71986E),
    Color(0xFF4D83A8),
    Color(0xFF8A70A8),
    Color(0xFFA65E35),
    Color(0xFFE06C9F),
    Color(0xFFE77B66),
    Color(0xFFC94B45),
    Color(0xFF3B9A92),
    Color(0xFFF28C45),
  ];

  static const _widths = <double>[3.5, 6.5, 10.5];

  late List<DoodleStroke> _strokes;
  final ValueNotifier<int> _canvasRevision = ValueNotifier<int>(0);
  final GlobalKey _paperKey = GlobalKey();
  Color _selectedColor = _palette.first;
  double _selectedWidth = _widths[1];
  bool _eraserEnabled = false;
  Offset? _lastEraserPoint;
  bool _isSaving = false;
  bool _isExporting = false;
  late bool _isFavorite;
  bool _favoriteSaving = false;
  final Map<int, Offset> _activePointers = <int, Offset>{};
  int? _drawingPointer;
  bool _transforming = false;
  bool _waitForAllPointersUp = false;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _transformStartDistance = 1;
  double _transformStartZoom = 1;
  Offset _transformContentAnchor = Offset.zero;
  List<DoodleStroke>? _singlePointerSnapshot;
  Offset? _singlePointerStart;
  bool _singlePointerMoved = false;
  bool _strokeInterrupted = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialFavorite;
    _strokes =
        widget.initialDoodle?.strokes
            .map(
              (stroke) =>
                  stroke.copyWith(points: List<Offset>.from(stroke.points)),
            )
            .toList() ??
        <DoodleStroke>[];
  }

  Doodle get _doodle => Doodle(strokes: List.unmodifiable(_strokes));
  AppStrings get _s => AppStrings(widget.language);

  void _selectionHaptic() {
    if (widget.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _mediumHaptic() {
    if (widget.hapticsEnabled) HapticFeedback.mediumImpact();
  }

  Offset? _normalizedIfInside(Offset point, Size size) {
    if (point.dx < 0 ||
        point.dy < 0 ||
        point.dx > size.width ||
        point.dy > size.height) {
      return null;
    }
    return Offset(point.dx / size.width, point.dy / size.height);
  }

  void _startStrokeAt(Offset localPosition, Size size) {
    _selectionHaptic();
    final point = _normalizedIfInside(_toDrawingPosition(localPosition), size);
    if (point == null) {
      _strokeInterrupted = true;
      return;
    }
    _strokeInterrupted = false;
    if (_eraserEnabled) {
      _lastEraserPoint = point;
      _eraseAt(point, point, size);
      return;
    }
    setState(() {
      _strokes.add(
        DoodleStroke(
          points: <Offset>[point],
          colorValue: _selectedColor.toARGB32(),
          width: _selectedWidth,
        ),
      );
    });
  }

  void _extendStrokeAt(Offset localPosition, Size size) {
    final point = _normalizedIfInside(_toDrawingPosition(localPosition), size);
    if (point == null) {
      _strokeInterrupted = true;
      _lastEraserPoint = null;
      return;
    }
    if (_eraserEnabled) {
      _eraseAt(
        _strokeInterrupted ? point : (_lastEraserPoint ?? point),
        point,
        size,
      );
      _lastEraserPoint = point;
      _strokeInterrupted = false;
      return;
    }
    if (_strokeInterrupted) {
      setState(() {
        _strokes.add(
          DoodleStroke(
            points: <Offset>[point],
            colorValue: _selectedColor.toARGB32(),
            width: _selectedWidth,
          ),
        );
      });
      _strokeInterrupted = false;
      return;
    }
    if (_strokes.isEmpty) return;
    final last = _strokes.last;
    if (last.points.isNotEmpty &&
        (last.points.last - point).distanceSquared < 0.000004) {
      return;
    }
    last.points.add(point);
    _canvasRevision.value++;
  }

  Offset _toDrawingPosition(Offset viewportPosition) =>
      (viewportPosition - _pan) / _zoom;

  void _handlePointerDown(PointerDownEvent event, Size size) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 1 && !_waitForAllPointersUp) {
      _singlePointerSnapshot = _strokes
          .map(
            (stroke) =>
                stroke.copyWith(points: List<Offset>.from(stroke.points)),
          )
          .toList();
      _singlePointerStart = event.localPosition;
      _singlePointerMoved = false;
      _drawingPointer = event.pointer;
      _startStrokeAt(event.localPosition, size);
      return;
    }
    if (_activePointers.length >= 2) {
      if (!_singlePointerMoved && _singlePointerSnapshot != null) {
        setState(() => _strokes = _singlePointerSnapshot!);
        _canvasRevision.value++;
      }
      _drawingPointer = null;
      _lastEraserPoint = null;
      _singlePointerSnapshot = null;
      _singlePointerStart = null;
      _waitForAllPointersUp = true;
      _startTransformGesture();
    }
  }

  void _handlePointerMove(PointerMoveEvent event, Size size) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2) {
      if (!_transforming) _startTransformGesture();
      _updateTransform(size);
      return;
    }
    if (!_waitForAllPointersUp && _drawingPointer == event.pointer) {
      if (!_singlePointerMoved &&
          _singlePointerStart != null &&
          (event.localPosition - _singlePointerStart!).distance < 2) {
        return;
      }
      _singlePointerMoved = true;
      _extendStrokeAt(event.localPosition, size);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_drawingPointer == event.pointer) _drawingPointer = null;
    _lastEraserPoint = null;
    _strokeInterrupted = false;
    _singlePointerSnapshot = null;
    _singlePointerStart = null;
    _singlePointerMoved = false;
    if (_activePointers.length < 2) _transforming = false;
    if (_activePointers.isEmpty) _waitForAllPointersUp = false;
  }

  void _startTransformGesture() {
    if (_activePointers.length < 2) return;
    final points = _activePointers.values.take(2).toList(growable: false);
    final focal = Offset.lerp(points[0], points[1], .5)!;
    _transformStartDistance = (points[0] - points[1]).distance.clamp(
      1,
      double.infinity,
    );
    _transformStartZoom = _zoom;
    _transformContentAnchor = (focal - _pan) / _zoom;
    _transforming = true;
  }

  void _updateTransform(Size size) {
    final points = _activePointers.values.take(2).toList(growable: false);
    if (points.length < 2) return;
    final focal = Offset.lerp(points[0], points[1], .5)!;
    final distance = (points[0] - points[1]).distance;
    final nextZoom =
        (_transformStartZoom * (distance / _transformStartDistance)).clamp(
          1.0,
          4.0,
        );
    final proposedPan = focal - (_transformContentAnchor * nextZoom);
    final minPan = Offset(
      size.width * (1 - nextZoom),
      size.height * (1 - nextZoom),
    );
    setState(() {
      _zoom = nextZoom;
      _pan = Offset(
        proposedPan.dx.clamp(minPan.dx, 0.0),
        proposedPan.dy.clamp(minPan.dy, 0.0),
      );
    });
  }

  void _eraseAt(Offset from, Offset to, Size size) {
    final erased = eraseDoodleAlong(
      _strokes,
      from: from,
      to: to,
      canvasSize: size,
      eraserWidth: _selectedWidth,
    );
    if (Doodle(strokes: erased).hasSameContent(Doodle(strokes: _strokes))) {
      return;
    }
    setState(() {
      _strokes = erased;
      if (_strokes.isEmpty) _isFavorite = false;
    });
    _canvasRevision.value++;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    _selectionHaptic();
    setState(() {
      _strokes.removeLast();
      if (_strokes.isEmpty) _isFavorite = false;
    });
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _selectionHaptic();
    setState(() {
      _strokes.clear();
      _isFavorite = false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_strokes.isEmpty || _favoriteSaving) return;
    _selectionHaptic();
    final previous = _isFavorite;
    final next = !previous;
    setState(() {
      _isFavorite = next;
      _favoriteSaving = true;
    });
    var applied = true;
    try {
      applied =
          await widget.onFavoriteChanged?.call(_doodle.snapshot(), next) ??
          true;
    } catch (error, stackTrace) {
      debugPrint('Favori durumu değiştirilemedi: $error\n$stackTrace');
      applied = false;
    }
    if (!mounted) return;
    setState(() {
      _favoriteSaving = false;
      if (!applied) _isFavorite = previous;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    _mediumHaptic();
    final doodle = _doodle;
    final sourceRect = _paperRect();
    setState(() => _isSaving = true);
    if (!mounted) return;
    Navigator.of(context).pop(
      DoodleEditorResult(
        doodle: doodle,
        sourceRect: sourceRect,
        isFavorite: _isFavorite && doodle.strokes.isNotEmpty,
      ),
    );
  }

  Future<void> _download() async {
    if (_strokes.isEmpty || _isExporting) return;
    _selectionHaptic();
    setState(() => _isExporting = true);
    try {
      final doodle = _doodle.snapshot();
      final callback = widget.onDownload;
      if (callback != null) {
        await callback(widget.date, doodle);
      } else {
        await DoodleGalleryService.save(date: widget.date, doodle: doodle);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _downloadSnackBar(
            _s.t('Çizim galeriye kaydedildi', 'Drawing saved to gallery'),
          ),
        );
    } on DoodleGalleryPermissionException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _downloadSnackBar(
            _s.t(
              'Galeri izni verilmedi',
              'Photo library permission was not granted',
            ),
            error: true,
          ),
        );
    } on DoodleGalleryPluginUnavailableException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _downloadSnackBar(
            _s.t(
              'Galeri özelliği için uygulamayı tamamen kapatıp yeniden açın',
              'Fully close and reopen the app to enable gallery saving',
            ),
            error: true,
          ),
        );
    } catch (error, stackTrace) {
      debugPrint('Çizim galeriye kaydedilemedi: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _downloadSnackBar(
            _s.t('Çizim kaydedilemedi', 'Drawing could not be saved'),
            error: true,
          ),
        );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  SnackBar _downloadSnackBar(String message, {bool error = false}) {
    final theme = context.drawnTheme;
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB64F45) : theme.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      content: Text(
        message,
        style: TextStyle(
          color: theme.paper,
          fontFamily: 'PatrickHand',
          fontSize: 17,
        ),
      ),
    );
  }

  Rect? _paperRect() {
    final renderObject = _paperKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  @override
  void dispose() {
    _canvasRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawnTheme = context.drawnTheme;
    return Scaffold(
      key: const Key('doodle-editor-page'),
      backgroundColor: drawnTheme.page,
      body: SafeArea(
        child: CustomPaint(
          painter: _EditorBackgroundPainter(color: drawnTheme.texture),
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: _isSaving,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    children: [
                      _EditorHeader(
                        date: widget.date,
                        language: widget.language,
                        downloadEnabled: _strokes.isNotEmpty && !_isExporting,
                        onDownload: _download,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 22,
                                  right: 22,
                                  bottom: 0,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final size = Size.square(
                                              constraints.maxWidth,
                                            );
                                            return Listener(
                                              key: const Key('doodle-canvas'),
                                              behavior: HitTestBehavior.opaque,
                                              onPointerDown: (event) =>
                                                  _handlePointerDown(
                                                    event,
                                                    size,
                                                  ),
                                              onPointerMove: (event) =>
                                                  _handlePointerMove(
                                                    event,
                                                    size,
                                                  ),
                                              onPointerUp: _handlePointerEnd,
                                              onPointerCancel:
                                                  _handlePointerEnd,
                                              child: CustomPaint(
                                                key: _paperKey,
                                                painter: SketchPaperPainter(
                                                  paper: drawnTheme.paper,
                                                  ink: drawnTheme.ink,
                                                  shadow: drawnTheme.shadow,
                                                  borderWidth: 1.7,
                                                ),
                                                child: ClipPath(
                                                  clipper:
                                                      const SketchPaperClipper(),
                                                  child: ColoredBox(
                                                    color: drawnTheme.paper,
                                                    child: ClipRect(
                                                      child: Transform(
                                                        key: const Key(
                                                          'doodle-zoom-layer',
                                                        ),
                                                        transform:
                                                            Matrix4.identity()
                                                              ..translateByDouble(
                                                                _pan.dx,
                                                                _pan.dy,
                                                                0,
                                                                1,
                                                              )
                                                              ..scaleByDouble(
                                                                _zoom,
                                                                _zoom,
                                                                1,
                                                                1,
                                                              ),
                                                        alignment:
                                                            Alignment.topLeft,
                                                        child: CustomPaint(
                                                          painter: DoodlePainter(
                                                            doodle: _doodle,
                                                            cacheGeometry:
                                                                false,
                                                            repaint:
                                                                _canvasRevision,
                                                            darkInkReplacement:
                                                                Theme.of(
                                                                      context,
                                                                    ).brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? drawnTheme.ink
                                                                : null,
                                                          ),
                                                          child:
                                                              const SizedBox.expand(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const Positioned(
                                        top: -7,
                                        left: 0,
                                        right: 0,
                                        child: IgnorePointer(
                                          child: Center(
                                            child: SketchTape(
                                              width: 88,
                                              height: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Transform.rotate(
                                    angle: -.11,
                                    child: _FavoriteCanvasButton(
                                      favorite: _isFavorite,
                                      enabled:
                                          _strokes.isNotEmpty &&
                                          !_favoriteSaving,
                                      onTap: _toggleFavorite,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ColorPalette(
                        colors: _palette,
                        selected: _selectedColor,
                        onSelected: (color) {
                          _selectionHaptic();
                          setState(() {
                            _selectedColor = color;
                            _eraserEnabled = false;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          ..._widths.map(
                            (width) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _WidthButton(
                                width: width,
                                selected: width == _selectedWidth,
                                onTap: () {
                                  _selectionHaptic();
                                  setState(() {
                                    _selectedWidth = width;
                                  });
                                },
                              ),
                            ),
                          ),
                          _EraserButton(
                            key: const Key('eraser-doodle'),
                            selected: _eraserEnabled,
                            onTap: () {
                              _selectionHaptic();
                              setState(() => _eraserEnabled = !_eraserEnabled);
                            },
                          ),
                          const Spacer(),
                          _EditorToolButton(
                            key: const Key('undo-doodle'),
                            tooltip: _s.t('Geri al', 'Undo'),
                            onPressed: _strokes.isEmpty ? null : _undo,
                            icon: _EditorToolIcon.undo,
                          ),
                          _EditorToolButton(
                            key: const Key('clear-doodle'),
                            tooltip: _s.t('Temizle', 'Clear'),
                            onPressed: _strokes.isEmpty ? null : _clear,
                            icon: _EditorToolIcon.trash,
                            destructive: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          key: const Key('save-doodle'),
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.inverseSurface,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: Text(
                            _strokes.isEmpty
                                ? _s.t('Boş bırak', 'Leave empty')
                                : _s.t('Takvime yapıştır', 'Stick to calendar'),
                            style: const TextStyle(
                              fontFamily: 'PatrickHand',
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.date,
    required this.language,
    required this.downloadEnabled,
    required this.onDownload,
  });

  final DateTime date;
  final AppLanguage language;
  final bool downloadEnabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return Row(
      children: [
        _EditorToolButton(
          tooltip: AppStrings(language).t('Kapat', 'Close'),
          onPressed: Navigator.of(context).pop,
          icon: _EditorToolIcon.close,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                longDate(date, language),
                style: TextStyle(
                  color: theme.ink,
                  fontFamily: 'PatrickHand',
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings(
                  language,
                ).t('O gün neye benziyordu?', 'What did that day look like?'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.mutedInk,
                  fontFamily: 'PatrickHand',
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: .055,
          child: _EditorToolButton(
            key: const Key('download-doodle'),
            tooltip: AppStrings(
              language,
            ).t('Galeriye kaydet', 'Save to gallery'),
            onPressed: downloadEnabled ? onDownload : null,
            icon: _EditorToolIcon.download,
          ),
        ),
      ],
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final color = colors[index];
          final isSelected = color == selected;
          return Semantics(
            label: 'Renk seç',
            selected: isSelected,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: isSelected ? 37 : 32,
                height: isSelected ? 37 : 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WidthButton extends StatelessWidget {
  const _WidthButton({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? context.drawnTheme.selection.withValues(alpha: .72)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 22,
          height: width / 1.5,
          decoration: BoxDecoration(
            color: context.drawnTheme.ink,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _EraserButton extends StatelessWidget {
  const _EraserButton({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return Tooltip(
      message: 'Silgi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? theme.selection.withValues(alpha: .78)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: CustomPaint(painter: _EraserIconPainter(color: theme.ink)),
        ),
      ),
    );
  }
}

class _FavoriteCanvasButton extends StatelessWidget {
  const _FavoriteCanvasButton({
    required this.favorite,
    required this.enabled,
    required this.onTap,
  });

  final bool favorite;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    final red = enabled
        ? const Color(0xFFB64F45)
        : theme.mutedInk.withValues(alpha: .34);
    return Tooltip(
      message: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: favorite,
        label: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
        child: GestureDetector(
          key: const Key('toggle-doodle-favorite'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox.square(
            dimension: 44,
            child: CustomPaint(
              painter: _FavoriteButtonBackgroundPainter(
                fill: theme.paper.withValues(alpha: .92),
                outline: favorite ? red : theme.grid.withValues(alpha: .58),
              ),
              child: Center(
                child: HandDrawnHeart(color: red, filled: favorite, size: 27),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteButtonBackgroundPainter extends CustomPainter {
  const _FavoriteButtonBackgroundPainter({
    required this.fill,
    required this.outline,
  });

  final Color fill;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .52, 2)
      ..cubicTo(
        size.width * .80,
        1,
        size.width - 2,
        size.height * .22,
        size.width - 2.5,
        size.height * .52,
      )
      ..cubicTo(
        size.width - 2,
        size.height * .80,
        size.width * .74,
        size.height - 1.5,
        size.width * .46,
        size.height - 2,
      )
      ..cubicTo(
        size.width * .17,
        size.height - 1,
        1.5,
        size.height * .74,
        2.5,
        size.height * .44,
      )
      ..cubicTo(3, size.height * .15, size.width * .24, 2, size.width * .52, 2)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant _FavoriteButtonBackgroundPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.outline != outline;
}

class _EditorToolButton extends StatelessWidget {
  const _EditorToolButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.destructive = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final _EditorToolIcon icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    final enabled = onPressed != null;
    final iconColor = enabled
        ? (destructive ? const Color(0xFFB64F45) : theme.ink)
        : theme.mutedInk.withValues(alpha: .35);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: CustomPaint(
              painter: _EditorToolPainter(
                fill: theme.paper.withValues(alpha: enabled ? .88 : .45),
                outline: theme.grid.withValues(alpha: enabled ? .58 : .25),
                iconColor: iconColor,
                icon: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditorToolIcon { close, download, undo, trash }

class _EditorToolPainter extends CustomPainter {
  const _EditorToolPainter({
    required this.fill,
    required this.outline,
    required this.iconColor,
    required this.icon,
  });

  final Color fill;
  final Color outline;
  final Color iconColor;
  final _EditorToolIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final button = Path()
      ..moveTo(size.width * .52, 2)
      ..cubicTo(
        size.width * .79,
        1,
        size.width - 2,
        size.height * .20,
        size.width - 2.5,
        size.height * .50,
      )
      ..cubicTo(
        size.width - 2,
        size.height * .80,
        size.width * .76,
        size.height - 1.5,
        size.width * .47,
        size.height - 2,
      )
      ..cubicTo(
        size.width * .18,
        size.height - 1,
        1.5,
        size.height * .76,
        2.5,
        size.height * .45,
      )
      ..cubicTo(3, size.height * .16, size.width * .23, 2, size.width * .52, 2)
      ..close();
    canvas
      ..drawPath(button, Paint()..color = fill)
      ..drawPath(
        button,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round,
      );

    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (icon) {
      case _EditorToolIcon.close:
        canvas
          ..drawPath(
            Path()
              ..moveTo(size.width * .34, size.height * .31)
              ..quadraticBezierTo(
                size.width * .48,
                size.height * .48,
                size.width * .68,
                size.height * .70,
              ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(size.width * .69, size.height * .30)
              ..quadraticBezierTo(
                size.width * .53,
                size.height * .48,
                size.width * .32,
                size.height * .68,
              ),
            paint,
          );
      case _EditorToolIcon.download:
        canvas
          ..drawPath(
            Path()
              ..moveTo(size.width * .50, size.height * .23)
              ..cubicTo(
                size.width * .48,
                size.height * .36,
                size.width * .52,
                size.height * .48,
                size.width * .50,
                size.height * .62,
              )
              ..moveTo(size.width * .37, size.height * .50)
              ..quadraticBezierTo(
                size.width * .44,
                size.height * .57,
                size.width * .50,
                size.height * .63,
              )
              ..quadraticBezierTo(
                size.width * .57,
                size.height * .56,
                size.width * .64,
                size.height * .49,
              ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(size.width * .28, size.height * .69)
              ..quadraticBezierTo(
                size.width * .49,
                size.height * .73,
                size.width * .73,
                size.height * .68,
              ),
            paint,
          );
      case _EditorToolIcon.undo:
        canvas
          ..drawPath(
            Path()
              ..moveTo(size.width * .28, size.height * .38)
              ..cubicTo(
                size.width * .47,
                size.height * .20,
                size.width * .78,
                size.height * .29,
                size.width * .76,
                size.height * .54,
              )
              ..cubicTo(
                size.width * .74,
                size.height * .72,
                size.width * .54,
                size.height * .78,
                size.width * .39,
                size.height * .69,
              ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(size.width * .29, size.height * .38)
              ..quadraticBezierTo(
                size.width * .37,
                size.height * .38,
                size.width * .44,
                size.height * .43,
              )
              ..moveTo(size.width * .29, size.height * .38)
              ..quadraticBezierTo(
                size.width * .30,
                size.height * .29,
                size.width * .34,
                size.height * .23,
              ),
            paint,
          );
      case _EditorToolIcon.trash:
        canvas
          ..drawPath(
            Path()
              ..moveTo(size.width * .31, size.height * .34)
              ..quadraticBezierTo(
                size.width * .50,
                size.height * .31,
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
                size.height * .23,
                size.width * .59,
                size.height * .29,
              ),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(size.width * .36, size.height * .40)
              ..lineTo(size.width * .40, size.height * .75)
              ..quadraticBezierTo(
                size.width * .51,
                size.height * .80,
                size.width * .64,
                size.height * .75,
              )
              ..lineTo(size.width * .68, size.height * .40),
            paint,
          )
          ..drawLine(
            Offset(size.width * .48, size.height * .45),
            Offset(size.width * .49, size.height * .68),
            paint,
          )
          ..drawLine(
            Offset(size.width * .58, size.height * .45),
            Offset(size.width * .57, size.height * .68),
            paint,
          );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorToolPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.iconColor != iconColor ||
      oldDelegate.icon != icon;
}

class _EraserIconPainter extends CustomPainter {
  const _EraserIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .28, size.height * .63)
      ..lineTo(size.width * .54, size.height * .31)
      ..quadraticBezierTo(
        size.width * .6,
        size.height * .24,
        size.width * .68,
        size.height * .31,
      )
      ..lineTo(size.width * .77, size.height * .4)
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .47,
        size.width * .76,
        size.height * .54,
      )
      ..lineTo(size.width * .56, size.height * .75)
      ..lineTo(size.width * .36, size.height * .75)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(size.width * .48, size.height * .39),
      Offset(size.width * .67, size.height * .58),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .36, size.height * .76),
      Offset(size.width * .72, size.height * .76),
      paint..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _EraserIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EditorBackgroundPainter extends CustomPainter {
  const _EditorBackgroundPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 9.0; y < size.height; y += 19) {
      for (var x = (y.toInt().isEven ? 7.0 : 13.0); x < size.width; x += 23) {
        canvas.drawCircle(Offset(x, y), .45, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorBackgroundPainter oldDelegate) =>
      oldDelegate.color != color;
}
