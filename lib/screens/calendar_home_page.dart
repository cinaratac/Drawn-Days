import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../data/doodle_repository.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../services/app_review_service.dart';
import '../services/paper_sound_service.dart';
import '../services/reminder_service.dart';
import '../services/story_share_service.dart';
import '../services/today_home_widget_service.dart';
import '../theme/drawn_days_theme.dart';
import '../utils/calendar_utils.dart';
import '../widgets/day_flow.dart';
import '../widgets/doodle_editor_sheet.dart';
import '../widgets/doodle_painter.dart';
import '../widgets/month_calendar.dart';
import '../widgets/week_calendar.dart';
import '../widgets/hand_drawn_heart.dart';
import 'favorites_page.dart';
import 'settings_page.dart';

enum CalendarView { month, week, flow }

const _monthGridDoodlePrefix = 'month-grid:';
const _monthHeaderDoodlePrefix = 'month-header:';
const _monthCanvasDoodlePrefix = 'month-canvas:';

Color _calendarAccentForMonth(int month) => const <Color>[
  Color(0xFFB25F3D),
  Color(0xFF7B61A8),
  Color(0xFF3F8A68),
  Color(0xFFD18C32),
  Color(0xFFB64F63),
  Color(0xFF4A7FA7),
  Color(0xFF9C713B),
  Color(0xFF6B8D45),
  Color(0xFF8C5C9E),
  Color(0xFFB15F3C),
  Color(0xFF4A7FA7),
  Color(0xFF2F7A62),
][month - 1];

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({
    super.key,
    required this.repository,
    required this.reminderService,
    required this.appReviewService,
    required this.settings,
    required this.onSettingsChanged,
    this.today,
  });

  final DoodleRepository repository;
  final ReminderService reminderService;
  final AppReviewService appReviewService;
  final AppSettings settings;
  final Future<bool> Function(AppSettings settings) onSettingsChanged;
  final DateTime? today;

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _minimumDoodlesBeforeReviewRequest = 3;
  static const _maxReviewRequests = 3;
  static const _reviewRequestSpacing = Duration(days: 90);

  late DateTime _today;
  late DateTime _focusDate;
  late final ValueNotifier<DateTime> _visibleMonth;
  late final AnimationController _saveFlightController;
  final GlobalKey _bodyStackKey = GlobalKey();
  late CalendarView _view;
  int _todayRequest = 0;
  Map<String, Doodle> _doodles = <String, Doodle>{};
  Map<String, Doodle> _monthGridDoodles = <String, Doodle>{};
  Map<String, Doodle> _monthHeaderDoodles = <String, Doodle>{};
  Map<String, Doodle> _monthCanvasDoodles = <String, Doodle>{};
  final MonthDrawingController _monthDrawingController =
      MonthDrawingController();
  Future<void> _monthSaveQueue = Future<void>.value();
  final PaperSoundService _paperSoundService = PaperSoundService();
  bool _loading = true;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<Uri>? _notificationClickSubscription;
  bool _widgetEditorPending = false;
  bool _openingWidgetEditor = false;
  bool _sharing = false;
  _SaveFlight? _saveFlight;
  Offset _drawingModeButtonOffset = Offset.zero;

  AppStrings get _s => AppStrings(widget.settings.language);
  bool get _mondayFirst =>
      widget.settings.weekStart == WeekStartPreference.monday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = dateOnly(widget.today ?? DateTime.now());
    _focusDate = _today;
    _view = switch (widget.settings.startView) {
      StartViewPreference.month => CalendarView.month,
      StartViewPreference.week => CalendarView.week,
      StartViewPreference.flow => CalendarView.flow,
    };
    _visibleMonth = ValueNotifier<DateTime>(_today);
    _saveFlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _initializeHomeWidgetLink();
    _initializeNotificationLink();
    _loadDoodles();
  }

  @override
  void didUpdateWidget(covariant CalendarHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.language != widget.settings.language && !_loading) {
      _scheduleTodayWidgetSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSubscription?.cancel();
    _notificationClickSubscription?.cancel();
    unawaited(_paperSoundService.dispose());
    _saveFlightController.dispose();
    _visibleMonth.dispose();
    _monthDrawingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  Future<void> _loadDoodles() async {
    final storedDoodles = await widget.repository.loadAll();
    final doodles = <String, Doodle>{};
    final monthGridDoodles = <String, Doodle>{};
    final monthHeaderDoodles = <String, Doodle>{};
    final monthCanvasDoodles = <String, Doodle>{};
    _splitStoredDoodles(
      storedDoodles,
      daily: doodles,
      monthGrid: monthGridDoodles,
      monthHeader: monthHeaderDoodles,
      monthCanvas: monthCanvasDoodles,
    );
    if (!mounted) return;
    setState(() {
      _doodles = doodles;
      _monthGridDoodles = monthGridDoodles;
      _monthHeaderDoodles = monthHeaderDoodles;
      _monthCanvasDoodles = monthCanvasDoodles;
      _loading = false;
    });
    final notificationLaunchUri = await widget.reminderService
        .takeInitialLaunchUri();
    if (!mounted) return;
    _handleEditorLaunch(notificationLaunchUri);
    _scheduleTodayWidgetSync();
    _openPendingWidgetEditor();
  }

  void _splitStoredDoodles(
    Map<String, Doodle> stored, {
    required Map<String, Doodle> daily,
    required Map<String, Doodle> monthGrid,
    required Map<String, Doodle> monthHeader,
    required Map<String, Doodle> monthCanvas,
  }) {
    for (final entry in stored.entries) {
      if (entry.key.startsWith(_monthGridDoodlePrefix)) {
        monthGrid[entry.key.substring(_monthGridDoodlePrefix.length)] =
            entry.value;
      } else if (entry.key.startsWith(_monthHeaderDoodlePrefix)) {
        monthHeader[entry.key.substring(_monthHeaderDoodlePrefix.length)] =
            entry.value;
      } else if (entry.key.startsWith(_monthCanvasDoodlePrefix)) {
        monthCanvas[entry.key.substring(_monthCanvasDoodlePrefix.length)] =
            entry.value;
      } else {
        daily[entry.key] = entry.value;
      }
    }
  }

  Map<String, Doodle> _allStoredDoodles() => <String, Doodle>{
    ..._doodles,
    for (final entry in _monthGridDoodles.entries)
      '$_monthGridDoodlePrefix${entry.key}': entry.value,
    for (final entry in _monthHeaderDoodles.entries)
      '$_monthHeaderDoodlePrefix${entry.key}': entry.value,
    for (final entry in _monthCanvasDoodles.entries)
      '$_monthCanvasDoodlePrefix${entry.key}': entry.value,
  };

  void _saveMonthDoodle(DateTime month, MonthDoodleLayer layer, Doodle doodle) {
    final monthKey = dateKey(DateTime(month.year, month.month));
    final prefix = switch (layer) {
      MonthDoodleLayer.header => _monthHeaderDoodlePrefix,
      MonthDoodleLayer.grid => _monthGridDoodlePrefix,
      MonthDoodleLayer.canvas => _monthCanvasDoodlePrefix,
    };
    final target = switch (layer) {
      MonthDoodleLayer.header => _monthHeaderDoodles,
      MonthDoodleLayer.grid => _monthGridDoodles,
      MonthDoodleLayer.canvas => _monthCanvasDoodles,
    };
    setState(() {
      if (doodle.isEmpty) {
        target.remove(monthKey);
      } else {
        target[monthKey] = doodle;
      }
    });
    final storageKey = '$prefix$monthKey';
    _monthSaveQueue = _monthSaveQueue
        .then(
          (_) => doodle.isEmpty
              ? widget.repository.delete(storageKey)
              : widget.repository.save(storageKey, doodle),
        )
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Month doodle save failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<void> _initializeHomeWidgetLink() async {
    await TodayHomeWidgetService.initialize();
    if (!mounted) return;
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetLaunch,
      onError: (_) {},
    );
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (mounted) _handleWidgetLaunch(launchUri);
    } catch (_) {
      // The plugin is registered after a full native restart.
    }
  }

  void _initializeNotificationLink() {
    _notificationClickSubscription = widget.reminderService.launchUris.listen(
      _handleEditorLaunch,
      onError: (_) {},
    );
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri?.scheme == 'drawndays' && uri?.host == 'calendar') {
      _refreshToday();
      final destination = uri!.pathSegments.firstOrNull;
      setState(() => _focusDate = _today);
      _selectView(
        destination == 'week' ? CalendarView.week : CalendarView.month,
      );
      return;
    }
    _handleEditorLaunch(uri);
  }

  void _handleEditorLaunch(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'drawndays' ||
        uri.host != 'draw' ||
        !uri.pathSegments.contains('today')) {
      return;
    }
    _refreshToday();
    _widgetEditorPending = true;
    _openPendingWidgetEditor();
  }

  void _refreshToday() {
    final refreshedToday = dateOnly(widget.today ?? DateTime.now());
    if (isSameDay(refreshedToday, _today)) return;
    final wasFocusedOnToday = isSameDay(_focusDate, _today);
    setState(() {
      _today = refreshedToday;
      if (wasFocusedOnToday) _focusDate = refreshedToday;
    });
    if (wasFocusedOnToday) _setVisibleMonth(refreshedToday);
    if (!_loading) _scheduleTodayWidgetSync();
  }

  void _openPendingWidgetEditor() {
    if (!_widgetEditorPending || _loading || _openingWidgetEditor || !mounted) {
      return;
    }
    _widgetEditorPending = false;
    _openingWidgetEditor = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _editDay(_today);
      _openingWidgetEditor = false;
      _openPendingWidgetEditor();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _syncTodayWidget() {
    return TodayHomeWidgetService.sync(
      date: _today,
      doodles: _doodles,
      language: widget.settings.language,
    );
  }

  void _scheduleTodayWidgetSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncTodayWidget());
    });
  }

  bool get _canMoveForward {
    return switch (_view) {
      CalendarView.month => true,
      CalendarView.week => !startOfWeek(
        _focusDate,
        mondayFirst: _mondayFirst,
      ).add(const Duration(days: 7)).isAfter(_today),
      CalendarView.flow => dateOnly(_focusDate).isBefore(_today),
    };
  }

  bool get _canMoveBack => switch (_view) {
    CalendarView.flow => _today.difference(dateOnly(_focusDate)).inDays < 3649,
    _ => true,
  };

  bool get _canUseLeftArrow => _canMoveBack;

  bool get _canUseRightArrow => _canMoveForward;

  void _selectionHaptic() {
    if (widget.settings.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _lightHaptic() {
    if (widget.settings.hapticsEnabled) HapticFeedback.lightImpact();
  }

  void _selectView(CalendarView view) {
    if (_view == view) return;
    setState(() {
      _view = view;
      if (view == CalendarView.flow && isAfterDay(_focusDate, _today)) {
        _focusDate = _today;
      }
    });
    if (view == CalendarView.month) _setVisibleMonth(_focusDate);
    if (widget.settings.hapticsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.selectionClick();
      });
    }
  }

  void _movePeriod(int direction) {
    if (_view == CalendarView.flow) {
      if (direction < 0 && !_canMoveBack) return;
      if (direction > 0 && !_canMoveForward) return;
      _selectionHaptic();
      setState(() {
        _focusDate = _focusDate.add(Duration(days: direction));
      });
      return;
    }

    if (_view == CalendarView.month) {
      final visibleMonth = _visibleMonth.value;
      final targetMonth = _dateInMonth(
        DateTime(visibleMonth.year, visibleMonth.month + direction),
      );
      _selectionHaptic();
      _setVisibleMonth(targetMonth);
      setState(() => _focusDate = targetMonth);
      return;
    }

    if (direction > 0 && !_canMoveForward) return;
    _selectionHaptic();
    setState(() => _focusDate = _focusDate.add(Duration(days: direction * 7)));
  }

  void _goToToday() {
    _selectionHaptic();
    final monthIsVisible = _view == CalendarView.month;
    setState(() {
      _focusDate = _today;
      _todayRequest++;
    });
    if (!monthIsVisible) _setVisibleMonth(_today);
  }

  void _setVisibleMonth(DateTime month) {
    final normalizedMonth = DateTime(month.year, month.month);
    final currentMonth = _visibleMonth.value;
    if (currentMonth.year == normalizedMonth.year &&
        currentMonth.month == normalizedMonth.month) {
      return;
    }
    _visibleMonth.value = normalizedMonth;
  }

  DateTime _dateInMonth(DateTime month) {
    final day = _focusDate.day.clamp(1, daysInMonth(month)).toInt();
    return DateTime(month.year, month.month, day);
  }

  void _changeMonth(DateTime month) {
    if (_focusDate.year == month.year && _focusDate.month == month.month) {
      return;
    }
    _selectionHaptic();
    setState(() => _focusDate = _dateInMonth(month));
  }

  void _changeFlowDate(DateTime date) {
    if (_view != CalendarView.flow || isSameDay(date, _focusDate)) return;
    setState(() => _focusDate = dateOnly(date));
  }

  Future<bool> _saveFavoriteImmediately(
    DateTime date,
    Doodle doodle,
    bool isFavorite,
  ) async {
    if (doodle.isEmpty) return false;
    final key = dateKey(date);
    final favorites = widget.settings.favoriteDateKeys.toSet();
    final favoriteChanged = isFavorite
        ? favorites.add(key)
        : favorites.remove(key);

    try {
      if (isFavorite) {
        final savedDoodle = doodle.snapshot();
        await widget.repository.save(key, savedDoodle);
        if (!mounted) return false;
        setState(() => _doodles[key] = savedDoodle);
        if (isSameDay(date, _today)) {
          _scheduleTodayWidgetSync();
          unawaited(
            widget.reminderService.updateDate(
              date: date,
              hasDoodle: true,
              settings: widget.settings,
            ),
          );
        }
      }

      if (favoriteChanged) {
        final applied = await widget.onSettingsChanged(
          widget.settings.copyWith(
            favoriteDateKeys: (favorites.toList()..sort()),
          ),
        );
        if (!applied) return false;
      }
      return mounted;
    } catch (error, stackTrace) {
      debugPrint('Favori kaydedilemedi: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> _editDay(DateTime date, [Rect? targetRect]) async {
    if (isAfterDay(date, _today)) return;
    _lightHaptic();
    final key = dateKey(date);
    final result = await showDoodleEditor(
      context: context,
      date: date,
      initialDoodle: _doodles[key],
      initialFavorite: widget.settings.favoriteDateKeys.contains(key),
      onFavoriteChanged: (doodle, isFavorite) =>
          _saveFavoriteImmediately(date, doodle, isFavorite),
      hapticsEnabled: widget.settings.hapticsEnabled,
      language: widget.settings.language,
    );
    if (result == null || !mounted) return;
    final previousDoodle = _doodles[key];
    final resultDoodle = result.doodle;

    final favorites = widget.settings.favoriteDateKeys.toSet();
    final shouldBeFavorite = result.isFavorite && !resultDoodle.isEmpty;
    final favoriteChanged = shouldBeFavorite
        ? favorites.add(key)
        : favorites.remove(key);
    if (favoriteChanged) {
      final applied = await widget.onSettingsChanged(
        widget.settings.copyWith(
          favoriteDateKeys: (favorites.toList()..sort()),
        ),
      );
      if (!applied || !mounted) return;
    }

    if (resultDoodle.hasSameContent(previousDoodle)) return;

    if (resultDoodle.isEmpty) {
      await widget.repository.delete(key);
      if (!mounted) return;
      setState(() => _doodles.remove(key));
      if (isSameDay(date, _today)) {
        _scheduleTodayWidgetSync();
        unawaited(
          widget.reminderService.updateDate(
            date: date,
            hasDoodle: false,
            settings: widget.settings,
          ),
        );
      }
      return;
    }

    final savedDoodle = resultDoodle.snapshot();
    await widget.repository.save(key, savedDoodle);
    if (widget.settings.soundEnabled) {
      unawaited(_paperSoundService.playRandom());
    }
    if (!mounted) return;
    await _playSaveFlight(
      doodle: savedDoodle,
      sourceRect: result.sourceRect,
      targetRect: targetRect,
    );
    if (!mounted) return;
    setState(() {
      _doodles[key] = savedDoodle;
      _saveFlight = null;
    });
    if (isSameDay(date, _today)) {
      _scheduleTodayWidgetSync();
      unawaited(
        widget.reminderService.updateDate(
          date: date,
          hasDoodle: true,
          settings: widget.settings,
        ),
      );
    }
    unawaited(_maybeRequestReview());
  }

  Future<void> _playSaveFlight({
    required Doodle doodle,
    required Rect? sourceRect,
    required Rect? targetRect,
  }) async {
    final from = _bodyLocalRect(sourceRect);
    final to = _bodyLocalRect(targetRect);
    if (from == null || to == null) return;
    _saveFlightController.stop();
    setState(() {
      _saveFlight = _SaveFlight(doodle: doodle, from: from, to: to);
    });
    await _saveFlightController.forward(from: 0);
  }

  Rect? _bodyLocalRect(Rect? globalRect) {
    if (globalRect == null || globalRect.width <= 0 || globalRect.height <= 0) {
      return null;
    }
    final renderObject = _bodyStackKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.globalToLocal(globalRect.topLeft);
    final bottomRight = renderObject.globalToLocal(globalRect.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  Future<void> _maybeRequestReview() async {
    final settings = widget.settings;
    if (!widget.appReviewService.canOpenStoreListing) return;
    if (_doodles.length < _minimumDoodlesBeforeReviewRequest) return;
    if (settings.reviewRequestCount >= _maxReviewRequests) return;

    final now = DateTime.now();
    final lastRequest = settings.lastReviewRequestAt;
    if (lastRequest != null &&
        now.difference(lastRequest) < _reviewRequestSpacing) {
      return;
    }

    final saved = await widget.onSettingsChanged(
      settings.copyWith(
        reviewRequestCount: settings.reviewRequestCount + 1,
        lastReviewRequestAt: now,
      ),
    );
    if (!saved) return;

    try {
      await widget.appReviewService.requestReview();
    } catch (error, stackTrace) {
      debugPrint('Review request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openStoreListing() async {
    try {
      await widget.appReviewService.openStoreListing();
    } catch (error, stackTrace) {
      debugPrint('Open store listing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_s.operationFailed)));
    }
  }

  Future<void> _clearDoodles() async {
    await widget.repository.clearAll();
    if (!mounted) return;
    setState(() {
      _doodles = <String, Doodle>{};
      _monthGridDoodles = <String, Doodle>{};
      _monthHeaderDoodles = <String, Doodle>{};
      _monthCanvasDoodles = <String, Doodle>{};
    });
    if (widget.settings.favoriteDateKeys.isNotEmpty) {
      await widget.onSettingsChanged(
        widget.settings.copyWith(favoriteDateKeys: const <String>[]),
      );
    }
    _scheduleTodayWidgetSync();
    await widget.reminderService.updateDate(
      date: _today,
      hasDoodle: false,
      settings: widget.settings,
    );
  }

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Rect.fromLTWH(0, 0, 1, 1);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _openStoryShare() async {
    if (_sharing) return;
    final format = await showModalBottomSheet<StoryShareFormat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      showDragHandle: false,
      builder: (context) => _StoryShareSheet(
        strings: _s,
        today: _today,
        todayDoodle: _doodles[dateKey(_today)],
      ),
    );
    if (format == null || !mounted) return;

    final todayDoodle = _doodles[dateKey(_today)];
    if (format == StoryShareFormat.todaySquare && todayDoodle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_s.noDrawingToday)));
      return;
    }

    final shareMonth = DateTime(_focusDate.year, _focusDate.month);
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = messenger.showSnackBar(
      SnackBar(
        content: Text(_s.preparingShare),
        duration: const Duration(days: 1),
      ),
    );

    try {
      final bytes = await switch (format) {
        StoryShareFormat.monthGrid => StoryShareService.renderMonthGrid(
          month: shareMonth,
          doodles: _doodles,
          language: widget.settings.language,
        ),
        StoryShareFormat.todaySquare => StoryShareService.renderTodaySquare(
          date: _today,
          doodle: todayDoodle!,
          language: widget.settings.language,
        ),
        StoryShareFormat.recentWeek => StoryShareService.renderRecentWeek(
          today: _today,
          doodles: _doodles,
          language: widget.settings.language,
        ),
      };
      progress.close();
      if (!mounted) return;
      final fileName = switch (format) {
        StoryShareFormat.monthGrid =>
          'drawn-days-${shareMonth.year}-${shareMonth.month.toString().padLeft(2, '0')}.png',
        StoryShareFormat.todaySquare => 'drawn-days-${dateKey(_today)}.png',
        StoryShareFormat.recentWeek =>
          'drawn-days-last-7-days-${dateKey(_today)}.png',
      };
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: [fileName],
          sharePositionOrigin: _shareOrigin(),
        ),
      );
    } catch (_) {
      progress.close();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(_s.operationFailed)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _createBackup() async {
    final encoded = jsonEncode(<String, Object?>{
      'format': 'drawn-days-backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': widget.settings.toJson(),
      'doodles': _allStoredDoodles().map(
        (key, doodle) => MapEntry(key, doodle.toJson()),
      ),
    });
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['drawn-days-${dateKey(_today)}.json'],
        sharePositionOrigin: _shareOrigin(),
      ),
    );
  }

  Future<bool> _restoreBackup() async {
    final file = await FilePicker.pickFile();
    if (file == null) return false;
    try {
      final bytes = await file.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['format'] != 'drawn-days-backup') {
        return false;
      }
      final rawDoodles = decoded['doodles'];
      final rawSettings = decoded['settings'];
      if (rawDoodles is! Map || rawSettings is! Map) return false;
      final restoredDoodles = <String, Doodle>{};
      for (final entry in rawDoodles.entries) {
        if (entry.value is! Map) continue;
        restoredDoodles[entry.key.toString()] = Doodle.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
      }
      final restoredSettings = AppSettings.fromJson(
        Map<String, Object?>.from(rawSettings),
      ).copyWith(onboardingCompleted: widget.settings.onboardingCompleted);
      final settingsApplied = await widget.onSettingsChanged(restoredSettings);
      if (!settingsApplied) return false;
      await widget.repository.replaceAll(restoredDoodles);
      if (!mounted) return true;
      final daily = <String, Doodle>{};
      final monthGrid = <String, Doodle>{};
      final monthHeader = <String, Doodle>{};
      final monthCanvas = <String, Doodle>{};
      _splitStoredDoodles(
        restoredDoodles,
        daily: daily,
        monthGrid: monthGrid,
        monthHeader: monthHeader,
        monthCanvas: monthCanvas,
      );
      setState(() {
        _doodles = daily;
        _monthGridDoodles = monthGrid;
        _monthHeaderDoodles = monthHeader;
        _monthCanvasDoodles = monthCanvas;
      });
      _scheduleTodayWidgetSync();
      await widget.reminderService.updateDate(
        date: _today,
        hasDoodle: restoredDoodles.containsKey(dateKey(_today)),
        settings: restoredSettings,
      );
      return true;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    }
  }

  Future<void> _openSettings() async {
    _selectionHaptic();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          settings: widget.settings,
          doodleCount: _doodles.length,
          onSettingsChanged: widget.onSettingsChanged,
          onClearDoodles: _clearDoodles,
          onCreateBackup: _createBackup,
          onRestoreBackup: _restoreBackup,
          onRateApp: _openStoreListing,
          showRateApp: widget.appReviewService.canOpenStoreListing,
        ),
      ),
    );
  }

  Future<void> _openFavorites() async {
    _selectionHaptic();
    final selectedDate = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(
        builder: (context) => FavoritesPage(
          doodles: _doodles,
          favoriteDateKeys: widget.settings.favoriteDateKeys,
          language: widget.settings.language,
        ),
      ),
    );
    if (selectedDate != null && mounted) await _editDay(selectedDate);
  }

  Widget _buildCalendarViews() {
    return IndexedStack(
      index: _view.index,
      sizing: StackFit.expand,
      children: [
        RepaintBoundary(
          child: MonthCalendar(
            key: const ValueKey('month-pages'),
            month: _focusDate,
            today: _today,
            todayRequest: _todayRequest,
            isActive: _view == CalendarView.month,
            doodles: _doodles,
            monthGridDoodles: _monthGridDoodles,
            monthHeaderDoodles: _monthHeaderDoodles,
            monthCanvasDoodles: _monthCanvasDoodles,
            drawingController: _monthDrawingController,
            onMonthDoodleChanged: _saveMonthDoodle,
            onDayTap: _editDay,
            onVisibleMonthChanged: _setVisibleMonth,
            onMonthChanged: _changeMonth,
            language: widget.settings.language,
            mondayFirst: _mondayFirst,
          ),
        ),
        RepaintBoundary(
          child: WeekCalendar(
            key: const ValueKey('week-pages'),
            focusDate: _focusDate,
            today: _today,
            todayRequest: _todayRequest,
            isActive: _view == CalendarView.week,
            doodles: _doodles,
            onDayTap: _editDay,
            language: widget.settings.language,
            mondayFirst: _mondayFirst,
          ),
        ),
        RepaintBoundary(
          child: DayFlow(
            key: const ValueKey('day-flow'),
            today: _today,
            focusDate: _focusDate,
            todayRequest: _todayRequest,
            isActive: _view == CalendarView.flow,
            doodles: _doodles,
            onDayTap: _editDay,
            onVisibleDateChanged: _changeFlowDate,
            language: widget.settings.language,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final colors = baseTheme.colorScheme;
    final handwrittenTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'PatrickHand'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: 'PatrickHand',
      ),
    );
    final drawnTheme = context.drawnTheme;
    final paperColor = drawnTheme.page;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screenPadding = MediaQuery.paddingOf(context);
    const modeButtonWidth = 38.0;
    const modeButtonHeight = 34.0;
    const modeButtonRight = 14.0;
    final modeButtonBottom = 104 + screenPadding.bottom;
    return Theme(
      data: handwrittenTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: paperColor,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: paperColor,
        ),
        child: Scaffold(
          backgroundColor: paperColor,
          extendBody: true,
          bottomNavigationBar: CalendarBottomNavigation(
            selected: _view,
            onSelected: _selectView,
            strings: _s,
          ),
          body: Stack(
            key: _bodyStackKey,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _PaperTexturePainter(
                    background: drawnTheme.page,
                    speckle: drawnTheme.texture,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.paddingOf(context).top),
                      const SizedBox(height: 50, child: _TopSpiral()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
                        child: _CalendarAppBar(
                          onShare: _sharing ? null : _openStoryShare,
                          onFavorites: _openFavorites,
                          onSettings: _openSettings,
                          strings: _s,
                          foregroundColor: drawnTheme.ink,
                        ),
                      ),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _visibleMonth,
                        builder: (context, visibleMonth, child) {
                          final title = switch (_view) {
                            CalendarView.month => monthTitle(
                              visibleMonth,
                              widget.settings.language,
                            ),
                            CalendarView.week => weekTitle(
                              _focusDate,
                              language: widget.settings.language,
                              mondayFirst: _mondayFirst,
                            ),
                            CalendarView.flow => longDate(
                              _focusDate,
                              widget.settings.language,
                            ),
                          };
                          final periodBar = _CalendarPeriodBar(
                            title: title,
                            accentColor: _calendarAccentForMonth(
                              _view == CalendarView.month
                                  ? visibleMonth.month
                                  : _focusDate.month,
                            ),
                            strings: _s,
                            onToday: _goToToday,
                            onBack: _canUseLeftArrow
                                ? () => _movePeriod(-1)
                                : null,
                            onForward: _canUseRightArrow
                                ? () => _movePeriod(1)
                                : null,
                          );
                          if (_view != CalendarView.month) return periodBar;
                          return ValueListenableBuilder<Doodle?>(
                            valueListenable:
                                _monthDrawingController.headerDoodle,
                            builder: (context, headerDoodle, child) {
                              return Stack(
                                children: [
                                  periodBar,
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      ignoring:
                                          !_monthDrawingController.active ||
                                          !_monthDrawingController
                                              .drawingEnabled,
                                      child: Listener(
                                        key: _monthDrawingController.headerKey,
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown:
                                            _monthDrawingController.pointerDown,
                                        onPointerMove:
                                            _monthDrawingController.pointerMove,
                                        onPointerUp:
                                            _monthDrawingController.pointerUp,
                                        onPointerCancel:
                                            _monthDrawingController.pointerUp,
                                        child: CustomPaint(
                                          key: const Key(
                                            'month-header-drawing-surface',
                                          ),
                                          painter: DoodlePainter(
                                            doodle:
                                                headerDoodle ??
                                                const Doodle(
                                                  strokes: <DoodleStroke>[],
                                                ),
                                            fitSquare: false,
                                            cacheGeometry: false,
                                            darkInkReplacement: dark
                                                ? drawnTheme.ink
                                                : null,
                                          ),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _loading
                              ? Center(
                                  key: const ValueKey('loading'),
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                )
                              : _buildCalendarViews(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: modeButtonRight,
                bottom: modeButtonBottom,
                child: Transform.translate(
                  offset: _drawingModeButtonOffset,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      final body = _bodyStackKey.currentContext
                          ?.findRenderObject();
                      if (body is! RenderBox || !body.hasSize) return;
                      final baseLeft =
                          body.size.width - modeButtonRight - modeButtonWidth;
                      final baseTop =
                          body.size.height -
                          modeButtonBottom -
                          modeButtonHeight;
                      final next = _drawingModeButtonOffset + details.delta;
                      setState(() {
                        _drawingModeButtonOffset = Offset(
                          next.dx.clamp(
                            -baseLeft,
                            body.size.width - modeButtonWidth - baseLeft,
                          ),
                          next.dy.clamp(
                            screenPadding.top - baseTop,
                            body.size.height -
                                screenPadding.bottom -
                                modeButtonHeight -
                                baseTop,
                          ),
                        );
                      });
                    },
                    child: ValueListenableBuilder<Doodle?>(
                      valueListenable: _monthDrawingController.headerDoodle,
                      builder: (context, doodle, child) {
                        if (!_monthDrawingController.active ||
                            _view != CalendarView.month) {
                          return const SizedBox.shrink();
                        }
                        return MonthDrawingModeButton(
                          key: const Key('fixed-month-drawing-mode'),
                          drawingEnabled:
                              _monthDrawingController.drawingEnabled,
                          onTap: _monthDrawingController.toggleMode,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_saveFlight != null)
                Positioned.fill(
                  child: _SaveFlightOverlay(
                    flight: _saveFlight!,
                    animation: _saveFlightController,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveFlight {
  const _SaveFlight({
    required this.doodle,
    required this.from,
    required this.to,
  });

  final Doodle doodle;
  final Rect from;
  final Rect to;
}

class _SaveFlightOverlay extends StatelessWidget {
  const _SaveFlightOverlay({required this.flight, required this.animation});

  final _SaveFlight flight;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final move = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );
    final lift = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.42, curve: Curves.easeOutCubic),
    );
    final settle = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final rect = Rect.lerp(flight.from, flight.to, move.value)!;
          final shadowOpacity = 0.18 * (1 - settle.value);
          final borderOpacity = 0.8 * (1 - settle.value);
          final angle = -0.035 * (1 - move.value);
          final liftOffset = -18 * lift.value * (1 - move.value);

          return Stack(
            children: [
              Positioned.fromRect(
                rect: rect.translate(0, liftOffset),
                child: Transform.rotate(
                  angle: angle,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(
                          0xFFDFE3DF,
                        ).withValues(alpha: borderOpacity),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: shadowOpacity),
                          blurRadius: 28 * (1 - settle.value),
                          offset: Offset(0, 18 * (1 - settle.value)),
                        ),
                      ],
                    ),
                    child: ClipRect(
                      child: CustomPaint(
                        painter: DoodlePainter(
                          doodle: flight.doodle,
                          cacheGeometry: false,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget {
  const _CalendarAppBar({
    required this.onShare,
    required this.onFavorites,
    required this.onSettings,
    required this.strings,
    required this.foregroundColor,
  });

  final VoidCallback? onShare;
  final VoidCallback onFavorites;
  final VoidCallback onSettings;
  final AppStrings strings;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;

        return SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: compact ? 184 : 205,
                    height: 58,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        const Positioned(
                          left: 2,
                          right: 3,
                          bottom: 9,
                          height: 16,
                          child: CustomPaint(
                            painter: _BrushStrokePainter(
                              color: Color(0xFFE9C84F),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRect(
                            child: Image.asset(
                              'lib/assets/appname.png',
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.center,
                              color: foregroundColor,
                              colorBlendMode: BlendMode.srcIn,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _FavoritesAppBarButton(
                onTap: onFavorites,
                tooltip: strings.t('Favoriler', 'Favorites'),
              ),
              const SizedBox(width: 8),
              _PaintedAssetButton(
                key: const Key('open-settings'),
                tooltip: strings.settings,
                onTap: onSettings,
                assetPath: 'lib/assets/settingbutton.png',
                iconColor: const Color(0xFFAA5530),
                strokeColor: const Color(0xFFF0C65B),
                size: 64,
              ),
              const SizedBox(width: 8),
              _PaintedAssetButton(
                key: const Key('share-story'),
                tooltip: strings.share,
                onTap: onShare,
                assetPath: 'lib/assets/sharebutton.png',
                iconColor: const Color(0xFF4D83A8),
                strokeColor: const Color(0xFF9CC3D7),
                size: 64,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarPeriodBar extends StatelessWidget {
  const _CalendarPeriodBar({
    required this.title,
    required this.accentColor,
    required this.strings,
    required this.onToday,
    required this.onBack,
    required this.onForward,
  });

  final String title;
  final Color accentColor;
  final AppStrings strings;
  final VoidCallback onToday;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          const SizedBox(width: 2),
          _NavigationButton(
            key: const Key('previous-period'),
            assetPath: 'lib/assets/leftbutton.png',
            onTap: onBack,
            iconColor: const Color(0xFF2E704F),
            strokeColor: const Color(0xFF8EBB99),
            size: 64,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PaintedPeriodTitle(title: title, accentColor: accentColor),
          ),
          const SizedBox(width: 8),
          _NavigationButton(
            key: const Key('next-period'),
            assetPath: 'lib/assets/rightbutton.png',
            onTap: onForward,
            iconColor: const Color(0xFF2E704F),
            strokeColor: const Color(0xFF8EBB99),
            size: 64,
          ),
          const SizedBox(width: 8),
          _PaintedAssetButton(
            key: const Key('go-today'),
            tooltip: strings.today,
            onTap: onToday,
            assetPath: 'lib/assets/todaybutton.png',
            iconColor: const Color(0xFF8A58A8),
            strokeColor: const Color(0xFFD8B7E8),
            size: 64,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.assetPath,
    required this.onTap,
    required this.iconColor,
    required this.strokeColor,
    this.size = 40,
  });

  final String assetPath;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color strokeColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final opacity = onTap == null ? 0.34 : 1.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: size * (54 / 64),
          height: size,
          child: CustomPaint(
            painter: _HandDrawnIconOutlinePainter(
              color: strokeColor.withValues(alpha: opacity),
            ),
            child: Center(
              child: Image.asset(
                assetPath,
                width: size * 0.39,
                height: size * 0.39,
                color: iconColor.withValues(alpha: opacity),
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesAppBarButton extends StatelessWidget {
  const _FavoritesAppBarButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('open-favorites'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 54,
            height: 64,
            child: CustomPaint(
              painter: const _HandDrawnIconOutlinePainter(
                color: Color(0xFFE7A8A0),
              ),
              child: const Center(
                child: HandDrawnHeart(
                  color: Color(0xFFB64F45),
                  filled: false,
                  size: 27,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaintedAssetButton extends StatelessWidget {
  const _PaintedAssetButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.assetPath,
    required this.iconColor,
    required this.strokeColor,
    required this.size,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final String assetPath;
  final Color iconColor;
  final Color strokeColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final opacity = onTap == null ? 0.34 : 1.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: size * (54 / 64),
            height: size,
            child: CustomPaint(
              painter: _HandDrawnIconOutlinePainter(
                color: strokeColor.withValues(alpha: opacity),
              ),
              child: Center(
                child: Image.asset(
                  assetPath,
                  width: size * 0.39,
                  height: size * 0.39,
                  color: iconColor.withValues(alpha: opacity),
                  colorBlendMode: BlendMode.srcIn,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaintedPeriodTitle extends StatelessWidget {
  const _PaintedPeriodTitle({required this.title, required this.accentColor});

  final String title;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final yearMatch = RegExp(r'\s(\d{4})$').firstMatch(title);
    final year = yearMatch?.group(1);
    final label = yearMatch == null
        ? title
        : title.substring(0, yearMatch.start).trim();

    return SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: 9,
            height: 8,
            child: CustomPaint(
              painter: _HandDrawnUnderlinePainter(color: accentColor),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF173F32),
                    fontFamily: 'PatrickHand',
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (year != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    year,
                    style: const TextStyle(
                      color: Color(0xFF53605A),
                      fontFamily: 'PatrickHand',
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HandDrawnIconOutlinePainter extends CustomPainter {
  const _HandDrawnIconOutlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 52;
    final scaleY = size.height / 64;
    final path = Path()
      ..moveTo(27 * scaleX, 2.5 * scaleY)
      ..cubicTo(
        42 * scaleX,
        1.5 * scaleY,
        50.5 * scaleX,
        12 * scaleY,
        50 * scaleX,
        32 * scaleY,
      )
      ..cubicTo(
        49.5 * scaleX,
        52 * scaleY,
        41 * scaleX,
        62.5 * scaleY,
        26 * scaleX,
        61.5 * scaleY,
      )
      ..cubicTo(
        11 * scaleX,
        62 * scaleY,
        2 * scaleX,
        51 * scaleY,
        2.5 * scaleX,
        31 * scaleY,
      )
      ..cubicTo(
        3 * scaleX,
        12 * scaleY,
        11 * scaleX,
        3 * scaleY,
        28 * scaleX,
        3.4 * scaleY,
      )
      ..cubicTo(
        33 * scaleX,
        3.5 * scaleY,
        36 * scaleX,
        4.5 * scaleY,
        39 * scaleX,
        6 * scaleY,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * (scaleX < scaleY ? scaleX : scaleY)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HandDrawnIconOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HandDrawnUnderlinePainter extends CustomPainter {
  const _HandDrawnUnderlinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 200;
    final scaleY = size.height / 10;
    final path = Path()
      ..moveTo(3 * scaleX, 5 * scaleY)
      ..cubicTo(
        40 * scaleX,
        8 * scaleY,
        80 * scaleX,
        2 * scaleY,
        120 * scaleX,
        6 * scaleY,
      )
      ..cubicTo(
        150 * scaleX,
        8 * scaleY,
        175 * scaleX,
        3 * scaleY,
        197 * scaleX,
        5 * scaleY,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (scaleX < scaleY ? scaleX : scaleY)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HandDrawnUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BrushStrokePainter extends CustomPainter {
  const _BrushStrokePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.02,
        size.width * 0.48,
        size.height * 0.24,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.48,
        size.width,
        size.height * 0.18,
      )
      ..lineTo(size.width * 0.96, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height,
        size.width * 0.32,
        size.height * 0.72,
      )
      ..lineTo(size.width * 0.03, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TopSpiral extends StatelessWidget {
  const _TopSpiral();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _TopSpiralPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _TopSpiralPainter extends CustomPainter {
  const _TopSpiralPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = const Color(0xFF53605A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = const Color(0xFF53605A).withValues(alpha: 0.45);
    final count = (size.width / 17).ceil();
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
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 5, 4, 10, size.height - 13),
        const Radius.circular(7),
      );
      canvas.drawRRect(rect, wirePaint);
      canvas.drawCircle(Offset(x, size.height - 4), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter({required this.background, required this.speckle});

  final Color background;
  final Color speckle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final specklePaint = Paint()..color = speckle;
    for (var y = 9.0; y < size.height; y += 17) {
      for (var x = 7.0; x < size.width; x += 19) {
        final offset = ((x * 3 + y * 5).toInt() % 7) - 3;
        canvas.drawCircle(Offset(x + offset, y), 0.55, specklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.speckle != speckle;
}

class _StoryShareSheet extends StatelessWidget {
  const _StoryShareSheet({
    required this.strings,
    required this.today,
    required this.todayDoodle,
  });

  final AppStrings strings;
  final DateTime today;
  final Doodle? todayDoodle;

  @override
  Widget build(BuildContext context) {
    final drawnTheme = context.drawnTheme;
    final height = (MediaQuery.sizeOf(context).height * .63).clamp(
      510.0,
      550.0,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'PatrickHand'),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: drawnTheme.page,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border(
                      top: BorderSide(color: drawnTheme.ink, width: 2),
                      left: BorderSide(color: drawnTheme.ink, width: 2),
                      right: BorderSide(color: drawnTheme.ink, width: 2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const SizedBox(height: 17, child: _ShareHoles()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 17, 14, 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Text(
                                    strings.shareDrawing,
                                    style: TextStyle(
                                      color: drawnTheme.ink,
                                      fontFamily: 'PatrickHand',
                                      fontSize: 40,
                                      height: 1,
                                    ),
                                  ),
                                  const Positioned(
                                    left: 2,
                                    bottom: -10,
                                    width: 250,
                                    height: 8,
                                    child: CustomPaint(
                                      painter: _ShareUnderlinePainter(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: drawnTheme.paper,
                              elevation: 4,
                              shadowColor: const Color(0x44293B37),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                customBorder: const CircleBorder(),
                                child: SizedBox.square(
                                  dimension: 50,
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: drawnTheme.ink,
                                    size: 31,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                          child: Column(
                            children: [
                              Expanded(
                                child: _StoryShareOption(
                                  key: const Key('share-month-story'),
                                  kind: _SharePreviewKind.month,
                                  title: strings.monthStory,
                                  subtitle: strings.monthStorySubtitle,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(StoryShareFormat.monthGrid),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _StoryShareOption(
                                  key: const Key('share-today-square'),
                                  kind: _SharePreviewKind.today,
                                  title: strings.todaySquare,
                                  subtitle: strings.todaySquareSubtitle,
                                  today: today,
                                  doodle: todayDoodle,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(StoryShareFormat.todaySquare),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _StoryShareOption(
                                  key: const Key('share-recent-week'),
                                  kind: _SharePreviewKind.week,
                                  title: strings.recentWeekStory,
                                  subtitle: strings.recentWeekStorySubtitle,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop(StoryShareFormat.recentWeek),
                                ),
                              ),
                            ],
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
                    angle: -.018,
                    child: Container(
                      width: 98,
                      height: 30,
                      color: const Color(0xFFF2D974).withValues(alpha: .92),
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

class _StoryShareOption extends StatelessWidget {
  const _StoryShareOption({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.today,
    this.doodle,
  });

  final _SharePreviewKind kind;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final DateTime? today;
  final Doodle? doodle;

  @override
  Widget build(BuildContext context) => Material(
    color: context.drawnTheme.paper,
    elevation: 3,
    shadowColor: const Color(0x552C3838),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(23),
      side: BorderSide(color: context.drawnTheme.ink, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: _SharePreview(kind: kind, today: today, doodle: doodle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.drawnTheme.ink,
                      fontFamily: 'PatrickHand',
                      fontSize: 27,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.drawnTheme.mutedInk,
                      fontFamily: 'PatrickHand',
                      fontSize: 18,
                      height: 1.16,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.drawnTheme.ink,
              size: 31,
            ),
          ],
        ),
      ),
    ),
  );
}

enum _SharePreviewKind { month, today, week }

class _SharePreview extends StatelessWidget {
  const _SharePreview({required this.kind, this.today, this.doodle});
  final _SharePreviewKind kind;
  final DateTime? today;
  final Doodle? doodle;

  @override
  Widget build(BuildContext context) {
    final square = kind == _SharePreviewKind.today;
    return Center(
      child: Transform.rotate(
        angle: kind == _SharePreviewKind.week ? .035 : -.035,
        child: SizedBox(
          width: square ? 82 : 57,
          height: square ? 82 : 95,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFEF8),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33293B37),
                        blurRadius: 7,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: kind == _SharePreviewKind.today
                      ? Stack(
                          children: [
                            if (doodle != null)
                              Positioned.fill(
                                child: DoodlePreview(
                                  doodle: doodle!,
                                  padding: const EdgeInsets.all(4),
                                  adaptDarkInk: false,
                                ),
                              )
                            else
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _ShareFacePainter(),
                                ),
                              ),
                            Positioned(
                              left: 7,
                              top: 5,
                              child: Text(
                                '${today?.day ?? ''}',
                                style: const TextStyle(
                                  color: Color(0xFF1F3A2D),
                                  fontFamily: 'PatrickHand',
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ],
                        )
                      : CustomPaint(
                          painter: _ShareGridPreviewPainter(
                            week: kind == _SharePreviewKind.week,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: -5,
                left: square ? 26 : 15,
                child: Container(
                  width: square ? 31 : 27,
                  height: 11,
                  color:
                      (kind == _SharePreviewKind.month
                              ? const Color(0xFFA9C7DC)
                              : kind == _SharePreviewKind.today
                              ? const Color(0xFFF2D974)
                              : const Color(0xFFE8B9A0))
                          .withValues(alpha: .9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareHoles extends StatelessWidget {
  const _ShareHoles();
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _ShareHolesPainter(),
    child: const SizedBox.expand(),
  );
}

class _ShareHolesPainter extends CustomPainter {
  const _ShareHolesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 26).floor();
    final gap = size.width / count;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(gap * (i + .5), size.height / 2),
        4.5,
        Paint()..color = const Color(0xFFCFC8B4),
      );
      canvas.drawCircle(
        Offset(gap * (i + .5), size.height / 2),
        4.5,
        Paint()
          ..color = const Color(0xFF8C8672)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShareUnderlinePainter extends CustomPainter {
  const _ShareUnderlinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(2, size.height * .6)
        ..cubicTo(
          size.width * .25,
          0,
          size.width * .45,
          size.height,
          size.width * .66,
          size.height * .42,
        )
        ..cubicTo(
          size.width * .81,
          0,
          size.width * .91,
          size.height,
          size.width - 2,
          size.height * .35,
        ),
      Paint()
        ..color = const Color(0xFFA8603A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShareGridPreviewPainter extends CustomPainter {
  const _ShareGridPreviewPainter({required this.week});
  final bool week;
  @override
  void paint(Canvas canvas, Size size) {
    final columns = week ? 2 : 4;
    final rows = week ? 4 : 8;
    final grid = Paint()
      ..color = const Color(0xFF2B3A36).withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (var column = 1; column < columns; column++) {
      final x = size.width * column / columns;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var row = 1; row < rows; row++) {
      final y = size.height * row / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    const colors = [
      Color(0xFF4A7FA7),
      Color(0xFFA8603A),
      Color(0xFF8A5FB0),
      Color(0xFF2E6B4A),
      Color(0xFF2B3A36),
    ];
    for (
      var index = 0;
      index < math.min(columns * rows, week ? 7 : 18);
      index++
    ) {
      final column = index % columns;
      final row = index ~/ columns;
      final left = size.width * column / columns;
      final top = size.height * row / rows;
      final cellWidth = size.width / columns;
      final cellHeight = size.height / rows;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = week ? 1.5 : 1.05
        ..strokeCap = StrokeCap.round;
      if (index.isEven) {
        canvas.drawPath(
          Path()
            ..moveTo(left + cellWidth * .18, top + cellHeight * .65)
            ..lineTo(left + cellWidth * .42, top + cellHeight * .28)
            ..lineTo(left + cellWidth * .72, top + cellHeight * .68),
          paint,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(left + cellWidth * .5, top + cellHeight * .5),
            width: cellWidth * .58,
            height: cellHeight * .58,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShareGridPreviewPainter oldDelegate) =>
      oldDelegate.week != week;
}

class _ShareFacePainter extends CustomPainter {
  const _ShareFacePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2B3A36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .25, size.height * .42)
        ..quadraticBezierTo(
          size.width * .34,
          size.height * .28,
          size.width * .46,
          size.height * .4,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .57, size.height * .39)
        ..quadraticBezierTo(
          size.width * .7,
          size.height * .3,
          size.width * .82,
          size.height * .43,
        ),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .34, size.height * .7)
        ..quadraticBezierTo(
          size.width * .55,
          size.height * .82,
          size.width * .75,
          size.height * .68,
        ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CalendarBottomNavigation extends StatelessWidget {
  const CalendarBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.strings,
  });

  final CalendarView selected;
  final ValueChanged<CalendarView> onSelected;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final drawnTheme = context.drawnTheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          key: const Key('calendar-bottom-bar'),
          width: 286,
          child: Material(
            color: drawnTheme.navigation,
            elevation: 4,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Color(0xFF263A34), width: 2),
            ),
            clipBehavior: Clip.hardEdge,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  return IconThemeData(
                    color: states.contains(WidgetState.selected)
                        ? colors.primary
                        : drawnTheme.mutedInk,
                  );
                }),
              ),
              child: NavigationBar(
                height: 58,
                animationDuration: Duration.zero,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  return TextStyle(
                    color: states.contains(WidgetState.selected)
                        ? colors.primary
                        : drawnTheme.mutedInk,
                    fontFamily: 'PatrickHand',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  );
                }),
                selectedIndex: selected.index,
                onDestinationSelected: (index) =>
                    onSelected(CalendarView.values[index]),
                destinations: [
                  NavigationDestination(
                    key: const Key('view-month'),
                    icon: const _NavIcon(
                      icon: Icons.calendar_view_month_outlined,
                    ),
                    selectedIcon: const _NavIcon(
                      icon: Icons.calendar_view_month_rounded,
                      selected: true,
                    ),
                    label: strings.month,
                  ),
                  NavigationDestination(
                    key: const Key('view-week'),
                    icon: const _NavIcon(icon: Icons.view_week_outlined),
                    selectedIcon: const _NavIcon(
                      icon: Icons.view_week_rounded,
                      selected: true,
                    ),
                    label: strings.week,
                  ),
                  NavigationDestination(
                    key: const Key('view-flow'),
                    icon: const _NavIcon(icon: Icons.auto_stories_outlined),
                    selectedIcon: const _NavIcon(
                      icon: Icons.auto_stories_rounded,
                      selected: true,
                    ),
                    label: strings.dayByDay,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected)
            const Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              height: 6,
              child: CustomPaint(
                key: Key('selected-navigation-brush'),
                painter: _BrushStrokePainter(color: Color(0xFFE7C64D)),
              ),
            ),
          Positioned(
            top: selected ? 0 : 2,
            child: Icon(icon, size: selected ? 27 : 25),
          ),
        ],
      ),
    );
  }
}
