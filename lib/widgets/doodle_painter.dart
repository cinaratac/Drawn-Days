import 'package:flutter/material.dart';

import '../models/doodle.dart';
import '../theme/drawn_days_theme.dart';

class DoodlePainter extends CustomPainter {
  const DoodlePainter({
    required this.doodle,
    this.stickerOutline = false,
    this.cacheGeometry = true,
    this.darkInkReplacement,
    this.fitSquare = true,
    super.repaint,
  });

  final Doodle doodle;
  final bool stickerOutline;
  final bool cacheGeometry;
  final Color? darkInkReplacement;
  final bool fitSquare;

  static final Expando<_StrokeGeometry> _geometryCache =
      Expando<_StrokeGeometry>('doodle-stroke-geometry');

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final drawingSize = fitSquare ? Size.square(side) : size;
    final origin = fitSquare
        ? Offset((size.width - side) / 2, (size.height - side) / 2)
        : Offset.zero;

    for (final stroke in doodle.strokes) {
      if (stroke.points.isEmpty) continue;

      final scale = side / 360;
      final width = (stroke.width * scale).clamp(0.85, 18.0);
      final geometry = _geometryFor(stroke);

      canvas
        ..save()
        ..translate(origin.dx, origin.dy)
        ..scale(drawingSize.width, drawingSize.height);

      if (stickerOutline) {
        _drawGeometry(
          canvas,
          geometry,
          Paint()
            ..color = const Color(0xFFFFFDF8)
            ..strokeWidth = (width + (4 * scale).clamp(1.5, 5.0)) / side
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      }

      final strokeColor = Color(stroke.colorValue);
      final displayColor =
          darkInkReplacement != null && strokeColor.computeLuminance() <= 0.06
          ? darkInkReplacement!
          : strokeColor;
      _drawGeometry(
        canvas,
        geometry,
        Paint()
          ..color = displayColor
          ..strokeWidth = width / side
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.restore();
    }
  }

  _StrokeGeometry _geometryFor(DoodleStroke stroke) {
    if (cacheGeometry) {
      final cached = _geometryCache[stroke];
      if (cached != null) return cached;
    }

    final geometry = stroke.points.length == 1
        ? _StrokeGeometry.single(stroke.points.first)
        : _StrokeGeometry.path(_pathFor(stroke.points));
    if (cacheGeometry) _geometryCache[stroke] = geometry;
    return geometry;
  }

  Path _pathFor(List<Offset> points) {
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
    return path;
  }

  void _drawGeometry(Canvas canvas, _StrokeGeometry geometry, Paint paint) {
    final point = geometry.point;
    if (point != null) {
      // A line with a round cap has a diameter equal to its stroke width.
      // Drawing a single point as a stroked circle made its outline extend on
      // both sides of the radius, so dots appeared roughly twice as large as
      // the line they turned into. A filled circle matches the round line cap.
      canvas.drawCircle(
        point,
        paint.strokeWidth / 2,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(geometry.path!, paint);
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) =>
      oldDelegate.doodle != doodle ||
      oldDelegate.stickerOutline != stickerOutline ||
      oldDelegate.cacheGeometry != cacheGeometry ||
      oldDelegate.darkInkReplacement != darkInkReplacement ||
      oldDelegate.fitSquare != fitSquare;
}

class _StrokeGeometry {
  const _StrokeGeometry.single(this.point) : path = null;

  const _StrokeGeometry.path(this.path) : point = null;

  final Offset? point;
  final Path? path;
}

class DoodlePreview extends StatelessWidget {
  const DoodlePreview({
    super.key,
    required this.doodle,
    this.padding = const EdgeInsets.all(4),
    this.stickerOutline = false,
    this.adaptDarkInk = true,
  });

  final Doodle doodle;
  final EdgeInsets padding;
  final bool stickerOutline;
  final bool adaptDarkInk;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            isComplex: true,
            willChange: false,
            painter: DoodlePainter(
              doodle: doodle,
              stickerOutline: stickerOutline,
              darkInkReplacement:
                  adaptDarkInk &&
                      Theme.of(context).brightness == Brightness.dark
                  ? context.drawnTheme.ink
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
