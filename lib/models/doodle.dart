import 'dart:ui';

class Doodle {
  const Doodle({required this.strokes});

  final List<DoodleStroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
  };

  factory Doodle.fromJson(Map<String, Object?> json) {
    final rawStrokes = json['strokes'];
    if (rawStrokes is! List) {
      return const Doodle(strokes: <DoodleStroke>[]);
    }

    return Doodle(
      strokes: rawStrokes
          .whereType<Map>()
          .map(
            (stroke) =>
                DoodleStroke.fromJson(Map<String, Object?>.from(stroke)),
          )
          .where((stroke) => stroke.points.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class DoodleStroke {
  const DoodleStroke({
    required this.points,
    required this.colorValue,
    required this.width,
  });

  final List<Offset> points;
  final int colorValue;
  final double width;

  DoodleStroke copyWith({List<Offset>? points}) => DoodleStroke(
    points: points ?? this.points,
    colorValue: colorValue,
    width: width,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'points': points
        .map((point) => <double>[point.dx, point.dy])
        .toList(growable: false),
    'color': colorValue,
    'width': width,
  };

  factory DoodleStroke.fromJson(Map<String, Object?> json) {
    final rawPoints = json['points'];
    final points = <Offset>[];

    if (rawPoints is List) {
      for (final rawPoint in rawPoints.whereType<List>()) {
        if (rawPoint.length < 2) continue;
        final x = rawPoint[0];
        final y = rawPoint[1];
        if (x is num && y is num) {
          points.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }

    return DoodleStroke(
      points: points,
      colorValue: (json['color'] as num?)?.toInt() ?? 0xFF292621,
      width: (json['width'] as num?)?.toDouble() ?? 5,
    );
  }
}
