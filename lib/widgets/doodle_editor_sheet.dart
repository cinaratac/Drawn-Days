import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/doodle.dart';
import '../models/app_settings.dart';
import '../l10n/app_strings.dart';
import '../utils/calendar_utils.dart';
import 'doodle_painter.dart';

Future<Doodle?> showDoodleEditor({
  required BuildContext context,
  required DateTime date,
  Doodle? initialDoodle,
  bool hapticsEnabled = true,
  AppLanguage language = AppLanguage.turkish,
}) {
  return Navigator.of(context).push<Doodle>(
    MaterialPageRoute<Doodle>(
      builder: (context) => DoodleEditorPage(
        date: date,
        initialDoodle: initialDoodle,
        hapticsEnabled: hapticsEnabled,
        language: language,
      ),
    ),
  );
}

class DoodleEditorPage extends StatefulWidget {
  const DoodleEditorPage({
    super.key,
    required this.date,
    required this.hapticsEnabled,
    required this.language,
    this.initialDoodle,
  });

  final DateTime date;
  final bool hapticsEnabled;
  final AppLanguage language;
  final Doodle? initialDoodle;

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
  ];

  static const _widths = <double>[3.5, 6.5, 10.5];

  late List<DoodleStroke> _strokes;
  Color _selectedColor = _palette.first;
  double _selectedWidth = _widths[1];

  @override
  void initState() {
    super.initState();
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

  Offset _normalized(Offset point, Size size) {
    return Offset(
      (point.dx / size.width).clamp(0.0, 1.0),
      (point.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _startStroke(DragStartDetails details, Size size) {
    _selectionHaptic();
    setState(() {
      _strokes.add(
        DoodleStroke(
          points: <Offset>[_normalized(details.localPosition, size)],
          colorValue: _selectedColor.toARGB32(),
          width: _selectedWidth,
        ),
      );
    });
  }

  void _extendStroke(DragUpdateDetails details, Size size) {
    if (_strokes.isEmpty) return;
    final last = _strokes.last;
    setState(() {
      _strokes[_strokes.length - 1] = last.copyWith(
        points: <Offset>[
          ...last.points,
          _normalized(details.localPosition, size),
        ],
      );
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    _selectionHaptic();
    setState(_strokes.removeLast);
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    _selectionHaptic();
    setState(_strokes.clear);
  }

  void _save() {
    _mediumHaptic();
    Navigator.of(context).pop(_doodle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('doodle-editor-page'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(
            children: [
              _EditorHeader(date: widget.date, language: widget.language),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size.square(constraints.maxWidth);
                        return GestureDetector(
                          key: const Key('doodle-canvas'),
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) => _startStroke(details, size),
                          onPanUpdate: (details) =>
                              _extendStroke(details, size),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFD8DDD9),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x190E0B07),
                                  blurRadius: 28,
                                  offset: Offset(0, 13),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: CustomPaint(
                                painter: DoodlePainter(doodle: _doodle),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        );
                      },
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
                  setState(() => _selectedColor = color);
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
                          setState(() => _selectedWidth = width);
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('undo-doodle'),
                    tooltip: _s.t('Geri al', 'Undo'),
                    onPressed: _strokes.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    key: const Key('clear-doodle'),
                    tooltip: _s.t('Temizle', 'Clear'),
                    onPressed: _strokes.isEmpty ? null : _clear,
                    icon: const Icon(Icons.delete_outline_rounded),
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
  const _EditorHeader({required this.date, required this.language});

  final DateTime date;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: AppStrings(language).t('Kapat', 'Close'),
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.close_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                longDate(date, language),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings(
                  language,
                ).t('O gün neye benziyordu?', 'What did that day look like?'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: colors
          .map((color) {
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
          })
          .toList(growable: false),
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
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 22,
          height: width / 1.5,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
