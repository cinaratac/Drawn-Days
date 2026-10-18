import 'dart:math' as math;

import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onStart});

  final Future<bool> Function() onStart;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _cream = Color(0xFFF7F3E8);
  static const _ink = Color(0xFF173F32);
  static const _muted = Color(0xFF53605A);
  static const _green = Color(0xFF2D684D);
  static const _pages = <_OnboardingCopy>[
    _OnboardingCopy(
      title: 'One day, one little drawing.',
      body:
          'Skip the long entries. Doodle how the day felt and watch your month fill up.',
      button: 'Get started',
    ),
    _OnboardingCopy(
      title: 'Tap a day. Draw how it felt.',
      body:
          'A few strokes are enough. Pick a color, doodle, done. No words needed.',
      button: 'Next',
    ),
    _OnboardingCopy(
      title: 'Your month, in your own marks.',
      body: "Flip back any time. It's a diary you can read at a glance.",
      button: 'Start drawing',
    ),
  ];

  final PageController _controller = PageController();
  int _page = 0;
  bool _starting = false;
  bool _doodleSheetPrecached = false;

  bool get _isLastPage => _page == _pages.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doodleSheetPrecached) return;
    _doodleSheetPrecached = true;
    Future.wait(
      List<Future<void>>.generate(
        12,
        (index) => precacheImage(
          AssetImage(
            'lib/assets/onboarding/doodles/doodle_${(index + 1).toString().padLeft(2, '0')}.png',
          ),
          context,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final started = await widget.onStart();
    if (mounted && !started) setState(() => _starting = false);
  }

  Future<void> _continue() async {
    if (_isLastPage) {
      await _start();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _pages[_page];
    return Scaffold(
      backgroundColor: _cream,
      body: CustomPaint(
        painter: const _OnboardingPaperPainter(),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 50, child: _OnboardingSpiral()),
              _OnboardingHeader(
                showSkip: !_isLastPage,
                onSkip: _starting ? null : _start,
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _OnboardingPanel(art: _OpeningCalendarArt(), pageIndex: 0),
                    _OnboardingPanel(art: _DrawingEditorArt(), pageIndex: 1),
                    _OnboardingPanel(art: _MonthGalleryArt(), pageIndex: 2),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  children: [
                    _PageIndicator(page: _page, count: _pages.length),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4A53605A),
                            blurRadius: 0,
                            offset: Offset(3, 5),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        key: Key(_isLastPage ? 'start-app' : 'next-guide-page'),
                        onPressed: _starting ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _green.withValues(
                            alpha: 0.55,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontFamily: 'PatrickHand',
                            fontSize: 23,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        child: _starting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(copy.button),
                                    const SizedBox(width: 10),
                                    Icon(
                                      _isLastPage
                                          ? Icons.edit_outlined
                                          : Icons.arrow_forward_rounded,
                                      size: 25,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 12, 2),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 194,
                  height: 54,
                  child: _OnboardingLogo(),
                ),
              ),
            ),
            if (showSkip)
              TextButton(
                key: const Key('skip-onboarding'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: _OnboardingPageState._muted,
                  textStyle: const TextStyle(
                    fontFamily: 'PatrickHand',
                    fontSize: 19,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFB15F3C),
                    decorationThickness: 1.6,
                  ),
                ),
                child: const Text('skip'),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({required this.art, required this.pageIndex});

  final Widget art;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        final copy = _OnboardingPageState._pages[pageIndex];
        final artHeight = switch (pageIndex) {
          0 => compact ? 300.0 : 350.0,
          1 => compact ? 292.0 : 356.0,
          _ => compact ? 285.0 : 348.0,
        };
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(12, compact ? 0 : 4, 12, 6),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: artHeight, child: art),
                SizedBox(height: compact ? 8 : 16),
                _OnboardingTitle(
                  title: copy.title,
                  pageIndex: pageIndex,
                  compact: compact,
                ),
                const SizedBox(height: 8),
                Text(
                  copy.body,
                  style: TextStyle(
                    color: _OnboardingPageState._muted,
                    fontFamily: 'PatrickHand',
                    fontSize: compact ? 16 : 19,
                    height: 1.25,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPaperPainter extends CustomPainter {
  const _OnboardingPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _OnboardingPageState._cream,
    );
    final random = math.Random(4);
    final grain = Paint()
      ..color = const Color(0xFF665433).withValues(alpha: 0.052);
    final count = (size.width * size.height / 120).round();
    for (var index = 0; index < count; index++) {
      final radius = index.isEven ? 0.35 : 0.55;
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        radius,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingSpiral extends StatelessWidget {
  const _OnboardingSpiral();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _OnboardingSpiralPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OnboardingSpiralPainter extends CustomPainter {
  const _OnboardingSpiralPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Paint()
      ..color = const Color(0xFF53605A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final holes = Paint()
      ..color = const Color(0xFF53605A).withValues(alpha: 0.42);
    final count = (size.width / 16).ceil();
    final gap = size.width / count;
    canvas.drawLine(
      Offset(0, size.height - 7),
      Offset(size.width, size.height - 7),
      Paint()
        ..color = const Color(0xFF53605A).withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );
    for (var index = 0; index < count; index++) {
      final x = gap * (index + 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 4.6, 2, 9.2, size.height - 12),
          const Radius.circular(6),
        ),
        wire,
      );
      canvas.drawCircle(Offset(x, size.height - 4), 1.3, holes);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingLogo extends StatelessWidget {
  const _OnboardingLogo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        const Positioned(
          left: 5,
          right: 3,
          bottom: 8,
          height: 15,
          child: CustomPaint(
            painter: _RoughStrokePainter(color: Color(0xFFE8C94F)),
          ),
        ),
        Positioned.fill(
          child: ClipRect(
            child: Image.asset(
              'lib/assets/appname.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.center,
              color: _OnboardingPageState._ink,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({
    required this.title,
    required this.pageIndex,
    required this.compact,
  });

  final String title;
  final int pageIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final underlineWidth = switch (pageIndex) {
      0 => 178.0,
      1 => 210.0,
      _ => 214.0,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _OnboardingPageState._ink,
            fontFamily: 'PatrickHand',
            fontSize: compact ? 34 : 42,
            height: 1.06,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
        Positioned(
          left: pageIndex == 0 ? 0 : (pageIndex == 1 ? 112 : 122),
          bottom: -3,
          width: compact ? underlineWidth * 0.78 : underlineWidth,
          height: 10,
          child: const CustomPaint(
            painter: _RoughStrokePainter(color: Color(0xFFE8C94F)),
          ),
        ),
      ],
    );
  }
}

class _RoughStrokePainter extends CustomPainter {
  const _RoughStrokePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.28,
        0,
        size.width * 0.52,
        size.height * 0.27,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.48,
        size.width,
        size.height * 0.15,
      )
      ..lineTo(size.width * 0.97, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height,
        size.width * 0.34,
        size.height * 0.72,
      )
      ..lineTo(size.width * 0.02, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.86));
  }

  @override
  bool shouldRepaint(covariant _RoughStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _OpeningCalendarArt extends StatelessWidget {
  const _OpeningCalendarArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridHeight = constraints.maxWidth * 0.75;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 2,
              height: gridHeight,
              child: CustomPaint(
                painter: const _OnboardingCalendarGridPainter(),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    return _OpeningCalendarCell(
                      day: day,
                      spriteIndex: day == 12 ? null : index,
                      isToday: day == 12,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: gridHeight + 5,
              height: 54,
              child: const CustomPaint(
                painter: _YourTurnArrowPainter(),
                child: Align(
                  alignment: Alignment(-0.05, -0.15),
                  child: Text(
                    'your turn',
                    style: TextStyle(
                      color: Color(0xFFB15F3C),
                      fontFamily: 'PatrickHand',
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OpeningCalendarCell extends StatelessWidget {
  const _OpeningCalendarCell({
    required this.day,
    required this.spriteIndex,
    required this.isToday,
  });

  final int day;
  final int? spriteIndex;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isToday)
          const Positioned.fill(
            left: 4,
            top: 4,
            right: 4,
            bottom: 4,
            child: CustomPaint(painter: _OnboardingTodayPainter()),
          ),
        if (spriteIndex case final sprite?)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 17, 5, 2),
              child: _DoodleSprite(index: sprite),
            ),
          ),
        Positioned(
          left: 7,
          top: 5,
          child: Text(
            '$day',
            style: const TextStyle(
              color: _OnboardingPageState._muted,
              fontFamily: 'PatrickHand',
              fontSize: 15,
            ),
          ),
        ),
        if (isToday)
          const Center(
            child: SizedBox.square(
              dimension: 32,
              child: CustomPaint(painter: _OnboardingPencilPainter()),
            ),
          ),
      ],
    );
  }
}

class _OnboardingCalendarGridPainter extends CustomPainter {
  const _OnboardingCalendarGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF718079).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    for (var column = 0; column <= 4; column++) {
      final x = size.width * column / 4;
      final drift = column.isEven ? 0.8 : -0.7;
      canvas.drawPath(
        Path()
          ..moveTo(x + drift, -3)
          ..cubicTo(
            x - drift,
            size.height * 0.32,
            x + drift,
            size.height * 0.68,
            x - (drift * 0.3),
            size.height + 4,
          ),
        paint,
      );
    }
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      final drift = row.isEven ? 0.8 : -0.7;
      canvas.drawPath(
        Path()
          ..moveTo(-3, y + drift)
          ..cubicTo(
            size.width * 0.3,
            y - drift,
            size.width * 0.7,
            y + drift,
            size.width + 4,
            y - (drift * 0.3),
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YourTurnArrowPainter extends CustomPainter {
  const _YourTurnArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB15F3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final target = Offset(size.width * 0.88, 3);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.69, 35)
        ..cubicTo(
          size.width * 0.77,
          43,
          size.width * 0.84,
          28,
          target.dx,
          target.dy,
        ),
      paint,
    );
    canvas
      ..drawPath(
        Path()
          ..moveTo(target.dx, target.dy)
          ..quadraticBezierTo(
            target.dx - 7,
            target.dy + 1,
            target.dx - 12,
            target.dy + 5,
          ),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(target.dx, target.dy)
          ..quadraticBezierTo(
            target.dx - 1,
            target.dy + 8,
            target.dx - 2,
            target.dy + 13,
          ),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingTodayPainter extends CustomPainter {
  const _OnboardingTodayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.52, 2)
      ..cubicTo(
        size.width * 0.83,
        1,
        size.width - 2,
        size.height * 0.20,
        size.width - 3,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width - 4,
        size.height * 0.84,
        size.width * 0.79,
        size.height - 2,
        size.width * 0.49,
        size.height - 3,
      )
      ..cubicTo(
        size.width * 0.20,
        size.height - 2,
        2,
        size.height * 0.80,
        3,
        size.height * 0.48,
      )
      ..cubicTo(
        4,
        size.height * 0.18,
        size.width * 0.20,
        3,
        size.width * 0.54,
        3,
      );
    canvas
      ..drawPath(path, Paint()..color = const Color(0xFFF2D66E))
      ..drawPath(
        path,
        Paint()
          ..color = _OnboardingPageState._green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingPencilPainter extends CustomPainter {
  const _OnboardingPencilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 24, size.height / 24);
    canvas
      ..save()
      ..scale(scale);
    final paint = Paint()
      ..color = _OnboardingPageState._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(4, 19)
          ..lineTo(5.2, 15)
          ..lineTo(15.8, 4.5)
          ..cubicTo(16.8, 3.5, 18.3, 3.5, 19.2, 4.5)
          ..cubicTo(20.1, 5.4, 20.1, 6.9, 19.2, 7.8)
          ..lineTo(8.4, 18.4)
          ..close(),
        paint,
      )
      ..drawLine(const Offset(14.2, 6.3), const Offset(17.5, 9.6), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MonthGalleryArt extends StatelessWidget {
  const _MonthGalleryArt();

  static const _days = <int>[1, 2, 3, 5, 6, 9, 10, 11, 12];
  static const _sprites = <int>[0, 1, 2, 4, 5, 7, 8, 9, 10];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 320;
        return Column(
          children: [
            SizedBox(
              height: compact ? 48 : 58,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundMonthArrow(icon: Icons.chevron_left_rounded),
                  Expanded(child: _GalleryMonthTitle()),
                  _RoundMonthArrow(icon: Icons.chevron_right_rounded),
                ],
              ),
            ),
            SizedBox(height: compact ? 3 : 7),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: compact ? 7 : 10,
                  mainAxisSpacing: compact ? 6 : 9,
                ),
                itemCount: _days.length,
                itemBuilder: (context, index) => Transform.rotate(
                  angle: index.isEven ? -0.018 : 0.014,
                  child: _CalendarTile(
                    day: _days[index],
                    spriteIndex: _sprites[index],
                    tapeColor: const [
                      Color(0xFFF1D762),
                      Color(0xFFB9D6E5),
                      Color(0xFFE8B8A5),
                      Color(0xFFB8D9C5),
                      Color(0xFFF1D762),
                      Color(0xFFB9D6E5),
                      Color(0xFFE8B8A5),
                      Color(0xFFB8D9C5),
                      Color(0xFFF1D762),
                    ][index],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundMonthArrow extends StatelessWidget {
  const _RoundMonthArrow({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 49,
      height: 49,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x190F1B14),
            blurRadius: 9,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: _OnboardingPageState._green, size: 34),
    );
  }
}

class _GalleryMonthTitle extends StatelessWidget {
  const _GalleryMonthTitle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          bottom: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'October',
                  style: TextStyle(
                    color: _OnboardingPageState._ink,
                    fontFamily: 'PatrickHand',
                    fontSize: 32,
                    height: 1,
                  ),
                ),
                SizedBox(width: 3),
                Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    '2026',
                    style: TextStyle(
                      color: _OnboardingPageState._muted,
                      fontFamily: 'PatrickHand',
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          bottom: 1,
          width: 190,
          height: 7,
          child: CustomPaint(
            painter: _WavyLinePainter(color: Color(0xFFB15F3C)),
          ),
        ),
      ],
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.day,
    required this.spriteIndex,
    required this.tapeColor,
  });

  final int day;
  final int? spriteIndex;
  final Color tapeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEF8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C53605A),
                  blurRadius: 8,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (spriteIndex case final sprite?)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(5, 17, 5, 3),
                      child: _DoodleSprite(index: sprite),
                    ),
                  ),
                Positioned(
                  left: 7,
                  top: 4,
                  child: Text(
                    '$day',
                    style: const TextStyle(
                      color: _OnboardingPageState._muted,
                      fontFamily: 'PatrickHand',
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: -0.025,
              child: Container(
                width: 39,
                height: 13,
                color: tapeColor.withValues(alpha: 0.83),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WavyLinePainter extends CustomPainter {
  const _WavyLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height * 0.58)
        ..cubicTo(
          size.width * 0.22,
          0,
          size.width * 0.42,
          size.height,
          size.width * 0.62,
          size.height * 0.43,
        )
        ..cubicTo(
          size.width * 0.77,
          0,
          size.width * 0.89,
          size.height * 0.85,
          size.width - 2,
          size.height * 0.36,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavyLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DoodleSprite extends StatelessWidget {
  const _DoodleSprite({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/onboarding/doodles/doodle_${(index + 1).toString().padLeft(2, '0')}.png',
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
  }
}

class _DrawingEditorArt extends StatelessWidget {
  const _DrawingEditorArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 320;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 9,
              right: 9,
              top: 12,
              bottom: compact ? 54 : 61,
              child: Transform.rotate(
                angle: -0.012,
                child: CustomPaint(
                  painter: const _EditorCardPainter(),
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 21,
                        top: 19,
                        child: Text(
                          'Saturday',
                          style: TextStyle(
                            color: _OnboardingPageState._muted,
                            fontFamily: 'PatrickHand',
                            fontSize: 19,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 21,
                        top: 44,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '17',
                              style: TextStyle(
                                color: _OnboardingPageState._ink,
                                fontFamily: 'PatrickHand',
                                fontSize: 47,
                                height: 0.85,
                              ),
                            ),
                            SizedBox(width: 8),
                            Padding(
                              padding: EdgeInsets.only(bottom: 1),
                              child: Text(
                                'Oct',
                                style: TextStyle(
                                  color: _OnboardingPageState._muted,
                                  fontFamily: 'PatrickHand',
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        right: 19,
                        top: 19,
                        width: 70,
                        height: 38,
                        child: CustomPaint(
                          painter: _TodayOutlinePainter(),
                          child: Center(
                            child: Text(
                              'today',
                              style: TextStyle(
                                color: _OnboardingPageState._green,
                                fontFamily: 'PatrickHand',
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(42, 87, 42, 31),
                          child: CustomPaint(painter: _CoffeeDoodlePainter()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 67,
              right: 68,
              bottom: 2,
              height: compact ? 75 : 88,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PencilTool(color: Color(0xFF293A35), selected: true),
                  _PencilTool(color: Color(0xFF4D88B3)),
                  _PencilTool(color: Color(0xFFB4663A)),
                  _PencilTool(color: Color(0xFF2E724F)),
                  _PencilTool(color: Color(0xFF9060B5)),
                ],
              ),
            ),
            Positioned(
              right: 3,
              bottom: 8,
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x180F1B14),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.undo_rounded,
                  color: _OnboardingPageState._ink,
                  size: 27,
                ),
              ),
            ),
            const Positioned(
              top: 1,
              left: 0,
              right: 0,
              child: Center(
                child: _TapeStrip(width: 94, color: Color(0xFFF1D762)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TapeStrip extends StatelessWidget {
  const _TapeStrip({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        width: width,
        height: 18,
        color: color.withValues(alpha: 0.78),
      ),
    );
  }
}

class _PencilTool extends StatelessWidget {
  const _PencilTool({required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: selected ? 86 : 78,
      child: CustomPaint(
        painter: _PencilToolPainter(color: color, selected: selected),
      ),
    );
  }
}

class _PencilToolPainter extends CustomPainter {
  const _PencilToolPainter({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = _OnboardingPageState._ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round;
    final bodyTop = size.height * 0.27;
    final body = Path()
      ..moveTo(4, bodyTop)
      ..lineTo(size.width / 2, 2)
      ..lineTo(size.width - 4, bodyTop)
      ..lineTo(size.width - 4, size.height - 5)
      ..lineTo(4, size.height - 5)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(body, outline);
    canvas.drawPath(
      Path()
        ..moveTo(4, bodyTop)
        ..lineTo(size.width / 2, 2)
        ..lineTo(size.width - 4, bodyTop)
        ..close(),
      Paint()..color = const Color(0xFFF2D5A8),
    );
    canvas.drawPath(
      Path()
        ..moveTo(4, bodyTop)
        ..lineTo(size.width / 2, 2)
        ..lineTo(size.width - 4, bodyTop),
      outline,
    );
    canvas.drawCircle(Offset(size.width / 2, 5), 2.4, Paint()..color = color);
    final eraser = Rect.fromLTWH(4, size.height - 13, size.width - 8, 8);
    canvas.drawRect(eraser, Paint()..color = const Color(0xFFE6A9A1));
    canvas.drawRect(eraser, outline);
    if (selected) {
      canvas.drawLine(
        Offset(1, size.height - 1),
        Offset(size.width - 1, size.height - 1),
        outline,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PencilToolPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}

class _EditorCardPainter extends CustomPainter {
  const _EditorCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(22, 3)
      ..cubicTo(size.width * 0.35, 1, size.width * 0.7, 4, size.width - 23, 2)
      ..cubicTo(size.width - 5, 3, size.width - 2, 12, size.width - 3, 25)
      ..lineTo(size.width - 2, size.height - 24)
      ..cubicTo(
        size.width - 3,
        size.height - 7,
        size.width - 13,
        size.height - 3,
        size.width - 26,
        size.height - 2,
      )
      ..lineTo(25, size.height - 2)
      ..cubicTo(8, size.height - 3, 4, size.height - 13, 4, size.height - 27)
      ..lineTo(2, 24)
      ..cubicTo(2, 9, 9, 4, 22, 3)
      ..close();
    canvas.drawShadow(path, const Color(0x6653605A), 5, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFEF8));
    canvas.drawPath(
      path,
      Paint()
        ..color = _OnboardingPageState._ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TodayOutlinePainter extends CustomPainter {
  const _TodayOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromLTWH(2, 3, size.width - 4, size.height - 7),
      Paint()
        ..color = _OnboardingPageState._green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoffeeDoodlePainter extends CustomPainter {
  const _CoffeeDoodlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 280, size.height / 230);
    final horizontalInset = (size.width - (280 * scale)) / 2;
    final verticalInset = (size.height - (230 * scale)) / 2;
    canvas
      ..save()
      ..translate(horizontalInset, verticalInset)
      ..scale(scale);
    final ink = Paint()
      ..color = const Color(0xFF293A35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final blue = Paint()
      ..color = const Color(0xFF4D88B3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final rust = Paint()
      ..color = const Color(0xFFB4663A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final green = Paint()
      ..color = _OnboardingPageState._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    for (final x in <double>[85, 140, 195]) {
      final steam = Path()
        ..moveTo(x, 38)
        ..cubicTo(x - 12, 54, x + 11, 67, x, 84);
      canvas.drawPath(steam, blue);
    }
    final heart = Path()
      ..moveTo(229, 50)
      ..cubicTo(213, 31, 195, 50, 229, 76)
      ..cubicTo(263, 50, 245, 31, 229, 50);
    canvas.drawPath(heart, rust);

    final cup = Path()
      ..moveTo(54, 101)
      ..lineTo(207, 101)
      ..cubicTo(207, 154, 196, 184, 168, 194)
      ..cubicTo(142, 203, 101, 200, 79, 181)
      ..cubicTo(59, 164, 54, 130, 54, 101);
    canvas.drawPath(cup, ink);
    final handle = Path()
      ..moveTo(208, 119)
      ..cubicTo(252, 111, 255, 168, 207, 172);
    canvas.drawPath(handle, ink);
    canvas.drawPath(
      Path()
        ..moveTo(22, 221)
        ..quadraticBezierTo(129, 243, 247, 216),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(232, 221)
        ..lineTo(260, 188)
        ..lineTo(274, 202)
        ..lineTo(239, 229)
        ..close(),
      ink,
    );
    canvas.drawLine(const Offset(260, 188), const Offset(274, 202), rust);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoffeeDoodlePainter oldDelegate) => false;
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (index) {
        final selected = index == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 16 : 12,
          height: selected ? 16 : 12,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected ? _OnboardingPageState._green : Colors.transparent,
            shape: BoxShape.circle,
            border: selected
                ? null
                : Border.all(color: const Color(0xFF9B9A88), width: 1.4),
          ),
        );
      }),
    );
  }
}

class _OnboardingCopy {
  const _OnboardingCopy({
    required this.title,
    required this.body,
    required this.button,
  });

  final String title;
  final String body;
  final String button;
}
