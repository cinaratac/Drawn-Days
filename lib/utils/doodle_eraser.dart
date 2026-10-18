import 'dart:math' as math;
import 'dart:ui';

import '../models/doodle.dart';

/// Erases stroke portions touched while the eraser moves from [from] to [to].
/// Collision detection happens in pixels, keeping the eraser circular on
/// drawing surfaces of every aspect ratio.
List<DoodleStroke> eraseDoodleAlong(
  List<DoodleStroke> strokes, {
  required Offset from,
  required Offset to,
  required Size canvasSize,
  required double eraserWidth,
}) {
  if (canvasSize.isEmpty) return strokes;
  final side = canvasSize.shortestSide;
  final scale = side / 360;
  final eraserRadius = (eraserWidth * scale).clamp(.85, 18.0).toDouble() / 2;
  final eraserStart = _toPixels(from, canvasSize);
  final eraserEnd = _toPixels(to, canvasSize);
  final result = <DoodleStroke>[];

  for (final stroke in strokes) {
    final strokeRadius = (stroke.width * scale).clamp(.85, 18.0).toDouble() / 2;
    final hitRadius = eraserRadius + strokeRadius;
    final hitRadiusSquared = hitRadius * hitRadius;
    if (!_strokeTouches(
      stroke.points,
      canvasSize,
      eraserStart,
      eraserEnd,
      hitRadiusSquared,
    )) {
      result.add(stroke);
      continue;
    }

    final points = _densify(
      stroke.points,
      canvasSize,
      step: math.max(.6, math.min(2, hitRadius * .6)),
    );
    var run = <Offset>[];

    void finishRun() {
      if (run.isEmpty) return;
      result.add(stroke.copyWith(points: run));
      run = <Offset>[];
    }

    for (var index = 0; index < points.length; index++) {
      final current = _toPixels(points[index], canvasSize);
      final touched =
          _distanceToSegmentSquared(current, eraserStart, eraserEnd) <=
          hitRadiusSquared;

      if (touched) {
        finishRun();
      } else {
        run.add(points[index]);
      }
    }
    finishRun();
  }
  return result;
}

bool _strokeTouches(
  List<Offset> points,
  Size size,
  Offset eraserStart,
  Offset eraserEnd,
  double radiusSquared,
) {
  if (points.isEmpty) return false;
  if (points.length == 1) {
    return _distanceToSegmentSquared(
          _toPixels(points.first, size),
          eraserStart,
          eraserEnd,
        ) <=
        radiusSquared;
  }
  for (var index = 1; index < points.length; index++) {
    if (_segmentDistanceSquared(
          _toPixels(points[index - 1], size),
          _toPixels(points[index], size),
          eraserStart,
          eraserEnd,
        ) <=
        radiusSquared) {
      return true;
    }
  }
  return false;
}

List<Offset> _densify(List<Offset> points, Size size, {required double step}) {
  if (points.length < 2) return List<Offset>.from(points);
  final result = <Offset>[points.first];
  for (var index = 1; index < points.length; index++) {
    final start = points[index - 1];
    final end = points[index];
    final pixelDistance =
        (_toPixels(end, size) - _toPixels(start, size)).distance;
    final divisions = math.max(1, (pixelDistance / step).ceil());
    for (var part = 1; part <= divisions; part++) {
      result.add(Offset.lerp(start, end, part / divisions)!);
    }
  }
  return result;
}

Offset _toPixels(Offset point, Size size) =>
    Offset(point.dx * size.width, point.dy * size.height);

double _segmentDistanceSquared(Offset a, Offset b, Offset c, Offset d) {
  if (_segmentsIntersect(a, b, c, d)) return 0;
  return math.min(
    math.min(
      _distanceToSegmentSquared(a, c, d),
      _distanceToSegmentSquared(b, c, d),
    ),
    math.min(
      _distanceToSegmentSquared(c, a, b),
      _distanceToSegmentSquared(d, a, b),
    ),
  );
}

bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  final abC = _cross(a, b, c);
  final abD = _cross(a, b, d);
  final cdA = _cross(c, d, a);
  final cdB = _cross(c, d, b);
  if (((abC < 0 && abD > 0) || (abC > 0 && abD < 0)) &&
      ((cdA < 0 && cdB > 0) || (cdA > 0 && cdB < 0))) {
    return true;
  }
  const epsilon = .000001;
  return (abC.abs() < epsilon && _isOnSegment(a, b, c)) ||
      (abD.abs() < epsilon && _isOnSegment(a, b, d)) ||
      (cdA.abs() < epsilon && _isOnSegment(c, d, a)) ||
      (cdB.abs() < epsilon && _isOnSegment(c, d, b));
}

bool _isOnSegment(Offset start, Offset end, Offset point) =>
    point.dx >= math.min(start.dx, end.dx) &&
    point.dx <= math.max(start.dx, end.dx) &&
    point.dy >= math.min(start.dy, end.dy) &&
    point.dy <= math.max(start.dy, end.dy);

double _cross(Offset a, Offset b, Offset point) =>
    ((b.dx - a.dx) * (point.dy - a.dy)) - ((b.dy - a.dy) * (point.dx - a.dx));

double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) return (point - start).distanceSquared;
  final projection =
      (((point - start).dx * segment.dx) + ((point - start).dy * segment.dy)) /
      lengthSquared;
  final closest = start + (segment * projection.clamp(0.0, 1.0));
  return (point - closest).distanceSquared;
}
