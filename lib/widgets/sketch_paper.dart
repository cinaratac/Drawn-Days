import 'package:flutter/material.dart';

abstract final class SketchPaperPath {
  static Path create(Size size, {Offset offset = Offset.zero}) {
    final dx = offset.dx;
    final dy = offset.dy;
    return Path()
      ..moveTo(5 + dx, 3 + dy)
      ..quadraticBezierTo(
        size.width * .48 + dx,
        1 + dy,
        size.width - 5 + dx,
        4 + dy,
      )
      ..quadraticBezierTo(
        size.width - 1 + dx,
        size.height * .48 + dy,
        size.width - 3 + dx,
        size.height - 6 + dy,
      )
      ..quadraticBezierTo(
        size.width * .52 + dx,
        size.height - 1 + dy,
        4 + dx,
        size.height - 4 + dy,
      )
      ..quadraticBezierTo(1 + dx, size.height * .52 + dy, 5 + dx, 3 + dy)
      ..close();
  }
}

class SketchPaperPainter extends CustomPainter {
  const SketchPaperPainter({
    required this.paper,
    required this.ink,
    required this.shadow,
    this.borderWidth = 1.4,
    this.shadowOffset = const Offset(3, 4),
  });

  final Color paper;
  final Color ink;
  final Color shadow;
  final double borderWidth;
  final Offset shadowOffset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      SketchPaperPath.create(size, offset: shadowOffset),
      Paint()..color = shadow,
    );
    canvas.drawPath(SketchPaperPath.create(size), Paint()..color = paper);
    canvas.drawPath(
      SketchPaperPath.create(size),
      Paint()
        ..color = ink.withValues(alpha: .72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant SketchPaperPainter oldDelegate) =>
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.shadow != shadow ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.shadowOffset != shadowOffset;
}

class SketchPaperClipper extends CustomClipper<Path> {
  const SketchPaperClipper();

  @override
  Path getClip(Size size) => SketchPaperPath.create(size);

  @override
  bool shouldReclip(covariant SketchPaperClipper oldClipper) => false;
}

class SketchTape extends StatelessWidget {
  const SketchTape({
    super.key,
    this.width = 76,
    this.height = 18,
    this.angle = -.025,
    this.color = const Color(0xFFF2D762),
  });

  final double width;
  final double height;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: SizedBox(
      width: width,
      height: height,
      child: ColoredBox(color: color.withValues(alpha: .72)),
    ),
  );
}
