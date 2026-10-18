import 'package:flutter/material.dart';

import '../models/app_settings.dart';

class AddDoodlePrompt extends StatefulWidget {
  const AddDoodlePrompt({
    super.key,
    required this.language,
    required this.onTap,
    this.scale = 1,
  });

  final AppLanguage language;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<AddDoodlePrompt> createState() => _AddDoodlePromptState();
}

class _AddDoodlePromptState extends State<AddDoodlePrompt> {
  bool _pressed = false;

  String get _label => switch (widget.language) {
    AppLanguage.turkish => 'Bir şey çiz',
    AppLanguage.english => 'Draw something',
  };

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = widget.onTap != null;
    final fillColor = _pressed && active ? colors.primary : Colors.white;
    final iconColor = _pressed && active ? colors.onPrimary : colors.primary;
    final buttonSize = 58 * widget.scale;
    final iconSize = 33 * widget.scale;
    final gap = 11 * widget.scale;
    final labelSize = (13 * widget.scale).clamp(9.0, 13.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fillColor,
          elevation: _pressed && active ? 0 : 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: CircleBorder(
            side: BorderSide(color: colors.primary.withValues(alpha: 0.18)),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: active ? _setPressed : null,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: buttonSize,
              child: Icon(Icons.add_rounded, color: iconColor, size: iconSize),
            ),
          ),
        ),
        SizedBox(height: gap),
        Text(
          _label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontSize: labelSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
