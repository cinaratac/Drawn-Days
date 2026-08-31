import 'package:flutter/widgets.dart';

typedef DayTapCallback = void Function(DateTime date, Rect targetRect);

Rect doodlePreviewPaintRect(Rect container, EdgeInsets padding) {
  final padded = Rect.fromLTRB(
    container.left + padding.left,
    container.top + padding.top,
    container.right - padding.right,
    container.bottom - padding.bottom,
  );
  if (padded.width <= 0 || padded.height <= 0) return container;

  final side = padded.width < padded.height ? padded.width : padded.height;
  return Rect.fromLTWH(
    padded.left + ((padded.width - side) / 2),
    padded.top + ((padded.height - side) / 2),
    side,
    side,
  );
}
