import 'dart:async';

import 'package:flutter/material.dart';

import 'data/doodle_repository.dart';
import 'data/settings_repository.dart';
import 'models/app_settings.dart';
import 'screens/calendar_home_page.dart';
import 'screens/onboarding_page.dart';
import 'services/app_review_service.dart';
import 'services/reminder_service.dart';
import 'theme/drawn_days_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsRepository = FileSettingsRepository();
  AppSettings settings;
  try {
    settings = await settingsRepository.load();
  } catch (error, stackTrace) {
    settings = const AppSettings();
    debugPrint('Initial settings load failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(
    DrawnDaysApp(
      settingsRepository: settingsRepository,
      initialSettings: settings,
    ),
  );
}

class DrawnDaysApp extends StatefulWidget {
  const DrawnDaysApp({
    super.key,
    this.repository,
    this.settingsRepository,
    this.reminderService,
    this.appReviewService,
    this.today,
    this.initialSettings,
  });

  final DoodleRepository? repository;
  final SettingsRepository? settingsRepository;
  final ReminderService? reminderService;
  final AppReviewService? appReviewService;
  final DateTime? today;
  final AppSettings? initialSettings;

  @override
  State<DrawnDaysApp> createState() => _DrawnDaysAppState();
}

class _DrawnDaysAppState extends State<DrawnDaysApp> {
  late final DoodleRepository _doodleRepository;
  late final SettingsRepository _settingsRepository;
  late final ReminderService _reminderService;
  late final AppReviewService _appReviewService;
  late AppSettings _settings;
  late bool _settingsLoaded;
  Future<void> _settingsUpdateTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings ?? const AppSettings();
    _settingsLoaded = widget.initialSettings != null;
    _doodleRepository = widget.repository ?? FileDoodleRepository();
    _settingsRepository =
        widget.settingsRepository ??
        (widget.repository == null
            ? FileSettingsRepository()
            : MemorySettingsRepository());
    _reminderService =
        widget.reminderService ??
        (widget.repository == null
            ? LocalReminderService()
            : MemoryReminderService());
    _appReviewService =
        widget.appReviewService ??
        (widget.repository == null
            ? StoreAppReviewService()
            : MemoryAppReviewService());
    if (_settingsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshRemindersAfterLaunch(_settings));
      });
    } else {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshRemindersAfterLaunch(settings));
    });
  }

  Future<void> _refreshRemindersAfterLaunch(AppSettings settings) async {
    try {
      final doodles = await _doodleRepository.loadAll();
      await _reminderService.initialize();
      await _reminderService.apply(
        settings,
        completedDateKeys: doodles.keys.toSet(),
      );
    } catch (error, stackTrace) {
      debugPrint('Reminder refresh after launch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _updateSettings(AppSettings settings) {
    final update = _settingsUpdateTail.then(
      (_) => _applySettingsUpdate(settings),
    );
    _settingsUpdateTail = update.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return update;
  }

  Future<bool> _applySettingsUpdate(AppSettings settings) async {
    final reminderChanged =
        settings.dailyReminderEnabled != _settings.dailyReminderEnabled ||
        settings.reminderHour != _settings.reminderHour ||
        settings.reminderMinute != _settings.reminderMinute ||
        settings.soundEnabled != _settings.soundEnabled ||
        settings.hapticsEnabled != _settings.hapticsEnabled ||
        settings.language != _settings.language;
    if (reminderChanged) {
      var reminderApplied = true;
      try {
        final doodles = await _doodleRepository.loadAll();
        reminderApplied = await _reminderService.apply(
          settings,
          completedDateKeys: doodles.keys.toSet(),
        );
      } catch (error, stackTrace) {
        reminderApplied = false;
        debugPrint('Reminder update failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      final enablingReminder =
          !_settings.dailyReminderEnabled && settings.dailyReminderEnabled;
      if (!reminderApplied && enablingReminder) return false;
    }
    if (!mounted) return false;
    setState(() => _settings = settings);
    await _settingsRepository.save(settings);
    return true;
  }

  ThemeData _themeFor(AppThemePreference preference) {
    const forestGreen = Color(0xFF315F46);
    const forestGreenDarkTheme = Color(0xFF82B596);
    final dark = preference == AppThemePreference.dark;
    final paper = preference == AppThemePreference.paper;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final background = dark
        ? const Color(0xFF171614)
        : paper
        ? const Color(0xFFF8F5EE)
        : const Color(0xFFF6F7F8);
    final surface = dark
        ? const Color(0xFF24211E)
        : paper
        ? const Color(0xFFFFFDF8)
        : Colors.white;
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: forestGreen,
      brightness: brightness,
      surface: surface,
    );
    final accent = dark ? forestGreenDarkTheme : forestGreen;
    final scheme = generatedScheme.copyWith(
      primary: accent,
      secondary: accent,
      tertiary: accent,
    );
    final drawnTheme = dark
        ? const DrawnDaysTheme(
            page: Color(0xFF171A18),
            paper: Color(0xFF242A26),
            ink: Color(0xFFF0F4F1),
            mutedInk: Color(0xFFB7C1BA),
            grid: Color(0xFF65736B),
            texture: Color(0x0FFFFFFF),
            shadow: Color(0x99000000),
            navigation: Color(0xFF242A26),
            selection: Color(0xFFD8BE55),
            isPaper: false,
          )
        : paper
        ? fallbackDrawnDaysTheme
        : const DrawnDaysTheme(
            page: Color(0xFFF3F6F4),
            paper: Color(0xFFFFFFFF),
            ink: Color(0xFF1D3029),
            mutedInk: Color(0xFF5E6B65),
            grid: Color(0xFF87938D),
            texture: Color(0x00000000),
            shadow: Color(0x2B53605A),
            navigation: Color(0xFFFFFFFF),
            selection: Color(0xFFF2D762),
            isPaper: false,
          );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[drawnTheme],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      dividerColor: scheme.outlineVariant,
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: scheme.onSurface,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.3,
        ),
        headlineSmall: TextStyle(
          color: scheme.onSurface,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          color: scheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drawn Days',
      theme: _themeFor(_settings.theme),
      home: _settingsLoaded
          ? _settings.onboardingCompleted
                ? CalendarHomePage(
                    repository: _doodleRepository,
                    reminderService: _reminderService,
                    appReviewService: _appReviewService,
                    settings: _settings,
                    onSettingsChanged: _updateSettings,
                    today: widget.today,
                  )
                : OnboardingPage(
                    onStart: () => _updateSettings(
                      _settings.copyWith(onboardingCompleted: true),
                    ),
                  )
          : const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
    );
  }
}
