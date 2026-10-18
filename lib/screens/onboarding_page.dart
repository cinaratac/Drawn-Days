import 'dart:math' as math;

import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onStart});

  final Future<bool> Function() onStart;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _cream = Color(0xFFFAF7F0);
  static const _ink = Color(0xFF142019);
  static const _muted = Color(0xFF5E6962);
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
      body: SafeArea(
        child: Column(
          children: [
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
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: Column(
                children: [
                  _PageIndicator(page: _page, count: _pages.length),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      key: Key(_isLastPage ? 'start-app' : 'next-guide-page'),
                      onPressed: _starting ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _green.withValues(alpha: 0.55),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
                                    size: 23,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                'lib/assets/app_icon.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Drawn Days',
                    maxLines: 1,
                    style: TextStyle(
                      color: _OnboardingPageState._ink,
                      fontFamily: 'BricolageGrotesque',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
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
                    fontFamily: 'DMSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Skip'),
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
        final compact = constraints.maxHeight < 610;
        final copy = _OnboardingPageState._pages[pageIndex];
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, compact ? 4 : 10, 20, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: compact ? 300 : 342, child: art),
                SizedBox(height: compact ? 18 : 28),
                Text(
                  copy.title,
                  style: TextStyle(
                    color: _OnboardingPageState._ink,
                    fontFamily: 'BricolageGrotesque',
                    fontSize: compact ? 31 : 36,
                    height: 1.03,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.body,
                  style: TextStyle(
                    color: _OnboardingPageState._muted,
                    fontFamily: 'DMSans',
                    fontSize: compact ? 15 : 16.5,
                    height: 1.45,
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

class _OpeningCalendarArt extends StatelessWidget {
  const _OpeningCalendarArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 7.0;
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: side,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              itemCount: 16,
              itemBuilder: (context, index) {
                final day = index + 1;
                final spriteIndex = switch (day) {
                  <= 7 => day - 1,
                  >= 9 && <= 12 => day - 2,
                  _ => null,
                };
                return _CalendarTile(
                  day: day,
                  spriteIndex: spriteIndex,
                  isToday: day == 13,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MonthGalleryArt extends StatelessWidget {
  const _MonthGalleryArt();

  static const _days = <int>[1, 2, 3, 5, 6, 9, 10, 11, 12];
  static const _sprites = <int>[0, 1, 2, 4, 5, 7, 8, 9, 10];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 11.0;
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(
            dimension: side,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
              ),
              itemCount: _days.length,
              itemBuilder: (context, index) => Transform.rotate(
                angle: index.isEven ? -0.012 : 0.012,
                child: _CalendarTile(
                  day: _days[index],
                  spriteIndex: _sprites[index],
                  elevated: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.day,
    required this.spriteIndex,
    this.isToday = false,
    this.elevated = false,
  });

  final int day;
  final int? spriteIndex;
  final bool isToday;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(elevated ? 18 : 15);
    return CustomPaint(
      foregroundPainter: isToday
          ? const _DashedRoundedBorderPainter(
              color: _OnboardingPageState._green,
              radius: 15,
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFEDF4EF) : Colors.white,
          borderRadius: radius,
          border: isToday
              ? null
              : Border.all(color: const Color(0xFFE3DED1), width: 1),
          boxShadow: elevated
              ? const [
                  BoxShadow(
                    color: Color(0x120F1B14),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              if (spriteIndex case final sprite?)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 16, 5, 5),
                    child: _DoodleSprite(index: sprite),
                  ),
                ),
              Positioned(
                left: 9,
                top: 6,
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isToday
                        ? _OnboardingPageState._green
                        : _OnboardingPageState._muted,
                    fontFamily: 'DMSans',
                    fontSize: elevated ? 12 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isToday)
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _OnboardingPageState._green,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
        final width = constraints.maxWidth;
        final toolbarWidth = width - 50;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: const Color(0xFFE3DED1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F1B14),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 20,
                      top: 16,
                      child: Text(
                        '13',
                        style: TextStyle(
                          color: _OnboardingPageState._ink,
                          fontFamily: 'BricolageGrotesque',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 14,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFECF3EE),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 7,
                          ),
                          child: Text(
                            'Today',
                            style: TextStyle(
                              color: _OnboardingPageState._green,
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(34, 54, 34, 40),
                        child: CustomPaint(painter: _CoffeeDoodlePainter()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              child: Container(
                width: toolbarWidth,
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFE3DED1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F1B14),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ColorDot(color: Color(0xFF293A35), selected: true),
                    _ColorDot(color: Color(0xFF4D88B3)),
                    _ColorDot(color: Color(0xFFB4663A)),
                    _ColorDot(color: Color(0xFF2E724F)),
                    _ColorDot(color: Color(0xFF9060B5)),
                    SizedBox(height: 34, child: VerticalDivider(width: 1)),
                    Icon(Icons.undo_rounded, color: _OnboardingPageState._ink),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      padding: selected ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: _OnboardingPageState._ink, width: 2)
            : null,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
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

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 6, metric.length)),
          paint,
        );
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
          width: selected ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? _OnboardingPageState._green
                : const Color(0xFFCDD1C8),
            borderRadius: BorderRadius.circular(99),
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
