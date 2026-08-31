import 'package:flutter/material.dart';

import '../models/doodle.dart';

class DoodlePainter extends CustomPainter {
  const DoodlePainter({
    required this.doodle,
    this.stickerOutline = false,
    this.cacheGeometry = true,
    super.repaint,
  });

  final Doodle doodle;
  final bool stickerOutline;
  final bool cacheGeometry;

  static final Expando<_StrokeGeometry> _geometryCache =
      Expando<_StrokeGeometry>('doodle-stroke-geometry');

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);

    for (final stroke in doodle.strokes) {
      if (stroke.points.isEmpty) continue;

      final scale = side / 360;
      final width = (stroke.width * scale).clamp(0.85, 18.0);
      final geometry = _geometryFor(stroke);

      canvas
        ..save()
        ..translate(origin.dx, origin.dy)
        ..scale(side, side);

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

      _drawGeometry(
        canvas,
        geometry,
        Paint()
          ..color = Color(stroke.colorValue)
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
      canvas.drawCircle(point, paint.strokeWidth / 2, paint);
      return;
    }
    canvas.drawPath(geometry.path!, paint);
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) =>
      oldDelegate.doodle != doodle ||
      oldDelegate.stickerOutline != stickerOutline ||
      oldDelegate.cacheGeometry != cacheGeometry;
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
  });

  final Doodle doodle;
  final EdgeInsets padding;
  final bool stickerOutline;

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
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
