import 'package:flutter/material.dart';

class HandDrawnHeart extends StatelessWidget {
  const HandDrawnHeart({
    super.key,
    required this.color,
    required this.filled,
    this.size = 30,
  });

  final Color color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: HandDrawnHeartPainter(color: color, filled: filled),
      ),
    );
  }
}

class HandDrawnHeartPainter extends CustomPainter {
  const HandDrawnHeartPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  Path _heart(Size size) => Path()
    ..moveTo(size.width * .50, size.height * .82)
    ..cubicTo(
      size.width * .43,
      size.height * .73,
      size.width * .16,
      size.height * .55,
      size.width * .17,
      size.height * .32,
    )
    ..cubicTo(
      size.width * .18,
      size.height * .14,
      size.width * .39,
      size.height * .10,
      size.width * .51,
      size.height * .29,
    )
    ..cubicTo(
      size.width * .63,
      size.height * .10,
      size.width * .84,
      size.height * .17,
      size.width * .82,
      size.height * .36,
    )
    ..cubicTo(
      size.width * .80,
      size.height * .55,
      size.width * .62,
      size.height * .70,
      size.width * .50,
      size.height * .82,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final heart = _heart(size);
    if (filled) {
      canvas.drawPath(
        heart,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        heart,
        Paint()
          ..color = color.withValues(alpha: .86)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(
        heart,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HandDrawnHeartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}
