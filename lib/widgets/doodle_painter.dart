import 'package:flutter/material.dart';

import '../models/doodle.dart';

class DoodlePainter extends CustomPainter {
  const DoodlePainter({required this.doodle, this.stickerOutline = false});

  final Doodle doodle;
  final bool stickerOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);

    for (final stroke in doodle.strokes) {
      if (stroke.points.isEmpty) continue;

      final scale = side / 360;
      final width = (stroke.width * scale).clamp(0.85, 18.0);
      final points = stroke.points
          .map(
            (point) => Offset(
              origin.dx + (point.dx * side),
              origin.dy + (point.dy * side),
            ),
          )
          .toList(growable: false);

      if (stickerOutline) {
        _drawStroke(
          canvas,
          points,
          Paint()
            ..color = const Color(0xFFFFFDF8)
            ..strokeWidth = width + (4 * scale).clamp(1.5, 5.0)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      }

      _drawStroke(
        canvas,
        points,
        Paint()
          ..color = Color(stroke.colorValue)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final midpoint = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) =>
      oldDelegate.doodle != doodle ||
      oldDelegate.stickerOutline != stickerOutline;
}

class DoodlePreview extends StatelessWidget {
  const DoodlePreview({
    super.key,
    required this.doodle,
    this.padding = const EdgeInsets.all(4),
    this.stickerOutline = true,
  });

  final Doodle doodle;
  final EdgeInsets padding;
  final bool stickerOutline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: padding,
          child: CustomPaint(
            painter: DoodlePainter(
              doodle: doodle,
              stickerOutline: stickerOutline,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
