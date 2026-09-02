import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onStart});

  final Future<bool> Function() onStart;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _starting = false;

  static const _pages = <_GuideContent>[
    _GuideContent(
      fallbackIcon: Icons.auto_stories_rounded,
      title: 'A visual diary, one day at a time.',
      body:
          'Drawn Days turns your calendar into a memory made of marks. No long entries. No pressure. Just what the day felt like.',
      accent: Color(0xFF315F46),
      showLogo: true,
    ),
    _GuideContent(
      fallbackIcon: Icons.gesture_rounded,
      assetPath: 'lib/assets/settingbutton.png',
      title: 'Scribble, don’t perform.',
      body:
          'This is not an art contest. A shape, a face, a messy line—anything can hold a memory. Your honest mark is enough.',
      accent: Color(0xFFF0B84B),
    ),
    _GuideContent(
      fallbackIcon: Icons.near_me_outlined,
      assetPath: 'lib/assets/todaybutton.png',
      title: 'Never lose today.',
      body:
          'Whenever you wander through past months, tap Today to return to the current day and leave your mark.',
      accent: Color(0xFF4D83A8),
    ),
    _GuideContent(
      fallbackIcon: Icons.ios_share_rounded,
      assetPath: 'lib/assets/sharebutton.png',
      title: 'Turn your days into stories.',
      body:
          'Share a full month, today’s drawing, or your last seven days in Instagram-ready layouts—directly from the share button.',
      accent: Color(0xFF8A70A8),
    ),
    _GuideContent(
      fallbackIcon: Icons.edit_rounded,
      assetPath: 'lib/assets/rightbutton.png',
      title: 'At least, draw one line.',
      body:
          'Unscribbled days are easy to forget. Come back each day, make one small mark, and let time become something you can see.',
      accent: Color(0xFFA65E35),
    ),
  ];

  bool get _isLastPage => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_isLastPage) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_starting) return;
    setState(() => _starting = true);
    final started = await widget.onStart();
    if (mounted && !started) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) =>
                    _GuidePage(content: _pages[index], pageNumber: index + 1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(_pages.length, (index) {
                      final selected = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected ? 24 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary
                              : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      key: Key(_isLastPage ? 'start-app' : 'next-guide-page'),
                      onPressed: _starting ? null : _continue,
                      child: _starting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isLastPage ? 'Start Drawn Days' : 'Next'),
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

class _GuidePage extends StatelessWidget {
  const _GuidePage({required this.content, required this.pageNumber});

  final _GuideContent content;
  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Drawn Days',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              const Spacer(),
              Text(
                '$pageNumber / ${_OnboardingPageState._pages.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 190,
              height: 190,
              padding: EdgeInsets.all(content.showLogo ? 12 : 42),
              decoration: BoxDecoration(
                color: content.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(52),
              ),
              child: _GuideArt(content: content),
            ),
          ),
          const Spacer(),
          Text(
            content.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 34,
              height: 1.08,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            content.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 17,
              height: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _GuideContent {
  const _GuideContent({
    required this.fallbackIcon,
    required this.title,
    required this.body,
    required this.accent,
    this.assetPath,
    this.showLogo = false,
  });

  final IconData fallbackIcon;
  final String title;
  final String body;
  final Color accent;
  final String? assetPath;
  final bool showLogo;
}

class _GuideArt extends StatelessWidget {
  const _GuideArt({required this.content});

  final _GuideContent content;

  @override
  Widget build(BuildContext context) {
    if (content.showLogo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Image.asset(
          'lib/assets/app_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(content.fallbackIcon, size: 94, color: content.accent);
          },
        ),
      );
    }

    final path = content.assetPath;
    if (path == null) {
      return Icon(content.fallbackIcon, size: 94, color: content.accent);
    }

    return Center(
      child: Image.asset(
        path,
        width: 110,
        height: 110,
        fit: BoxFit.contain,
        color: content.accent,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Icon(content.fallbackIcon, size: 94, color: content.accent);
        },
      ),
    );
  }
}
