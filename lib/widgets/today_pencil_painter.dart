import 'dart:typed_data';

import 'package:flutter/material.dart';

class TodayPencilPainter extends CustomPainter {
  const TodayPencilPainter({this.color = const Color(0xFF2E5D46)});

  static const _sourceSize = 29.365478515625;

  final Color color;

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
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * (scaleX < scaleY ? scaleX : scaleY)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(pencil.transform(transform), paint)
      ..drawPath(detail.transform(transform), paint);
  }

  @override
  bool shouldRepaint(covariant TodayPencilPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TodayPencilHighlightPainter extends CustomPainter {
  const TodayPencilHighlightPainter({
    this.color = const Color(0xFF315F46),
    this.fillColor = const Color(0xB8F6D978),
  });

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
  bool shouldRepaint(covariant TodayPencilHighlightPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}
