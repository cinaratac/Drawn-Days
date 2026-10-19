import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import '../widgets/doodle_painter.dart';
import '../widgets/hand_drawn_heart.dart';
import '../widgets/sketch_paper.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.doodles,
    required this.favoriteDateKeys,
    required this.language,
  });

  final Map<String, Doodle> doodles;
  final List<String> favoriteDateKeys;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    final strings = AppStrings(language);
    final entries =
        favoriteDateKeys
            .where((key) => doodles[key]?.isEmpty == false)
            .map(
              (key) => (
                key: key,
                date: DateTime.tryParse(key),
                doodle: doodles[key]!,
              ),
            )
            .where((entry) => entry.date != null)
            .toList()
          ..sort((first, second) => second.date!.compareTo(first.date!));

    return Scaffold(
      key: const Key('favorites-page'),
      backgroundColor: theme.page,
      body: SafeArea(
        child: CustomPaint(
          painter: _FavoritesTexturePainter(color: theme.texture),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _SketchBackButton(onTap: Navigator.of(context).pop),
                    const SizedBox(width: 12),
                    HandDrawnHeart(
                      color: const Color(0xFFB64F45),
                      filled: true,
                      size: 34,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        strings.t('Favoriler', 'Favorites'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.ink,
                          fontFamily: 'PatrickHand',
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 80, right: 24, top: 2),
                child: CustomPaint(
                  painter: const _ScribbleUnderlinePainter(
                    color: Color(0xFFB25F3D),
                  ),
                  child: const SizedBox(height: 8, width: double.infinity),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyFavorites(language: language)
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 13,
                              mainAxisSpacing: 17,
                              childAspectRatio: .80,
                            ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _FavoriteCard(
                            date: entry.date!,
                            doodle: entry.doodle,
                            language: language,
                            rotation: index.isEven ? -.012 : .014,
                            onTap: () => Navigator.of(context).pop(entry.date),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.date,
    required this.doodle,
    required this.language,
    required this.rotation,
    required this.onTap,
  });

  final DateTime date;
  final Doodle doodle;
  final AppLanguage language;
  final double rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return Transform.rotate(
      angle: rotation,
      child: GestureDetector(
        key: Key('favorite-card-${dateKey(date)}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SketchPaperPainter(
                  paper: theme.paper,
                  ink: theme.grid,
                  shadow: theme.shadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 14, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              longDate(date, language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.ink,
                                fontFamily: 'PatrickHand',
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const HandDrawnHeart(
                            color: Color(0xFFB64F45),
                            filled: true,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DoodlePreview(
                          doodle: doodle,
                          padding: const EdgeInsets.all(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -5,
              left: 44,
              right: 44,
              height: 15,
              child: SketchTape(
                width: double.infinity,
                height: 15,
                angle: indexTapeAngle(date.day),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double indexTapeAngle(int seed) => seed.isEven ? -.025 : .018;
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    final strings = AppStrings(language);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HandDrawnHeart(
              color: Color(0xFFB64F45),
              filled: false,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              strings.t('Henüz favori yok', 'No favorites yet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.ink,
                fontFamily: 'PatrickHand',
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.t(
                'Sevdiğin bir çizimi açıp kalbe dokun.',
                'Open a drawing you love and tap the heart.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.mutedInk,
                fontFamily: 'PatrickHand',
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchBackButton extends StatelessWidget {
  const _SketchBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.drawnTheme;
    return GestureDetector(
      key: const Key('close-favorites'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 46,
        child: CustomPaint(
          painter: _BackButtonPainter(paper: theme.paper, ink: theme.ink),
        ),
      ),
    );
  }
}

class _BackButtonPainter extends CustomPainter {
  const _BackButtonPainter({required this.paper, required this.ink});
  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromLTWH(2, 1, size.width - 4, size.height - 3),
      Paint()..color = paper,
    );
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .60, size.height * .27)
        ..quadraticBezierTo(
          size.width * .46,
          size.height * .42,
          size.width * .34,
          size.height * .52,
        )
        ..quadraticBezierTo(
          size.width * .47,
          size.height * .61,
          size.width * .61,
          size.height * .73,
        )
        ..moveTo(size.width * .35, size.height * .52)
        ..lineTo(size.width * .72, size.height * .51),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackButtonPainter oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.ink != ink;
}

class _ScribbleUnderlinePainter extends CustomPainter {
  const _ScribbleUnderlinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height * .55)
        ..cubicTo(
          size.width * .28,
          size.height * .10,
          size.width * .64,
          size.height * .90,
          size.width - 2,
          size.height * .43,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScribbleUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FavoritesTexturePainter extends CustomPainter {
  const _FavoritesTexturePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 7.0; y < size.height; y += 19) {
      for (var x = 9.0; x < size.width; x += 23) {
        canvas.drawCircle(Offset(x, y), .45, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FavoritesTexturePainter oldDelegate) =>
      oldDelegate.color != color;
}
