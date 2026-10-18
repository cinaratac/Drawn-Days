import 'dart:async';
import 'dart:convert';

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
import '../utils/calendar_utils.dart';
import '../widgets/day_flow.dart';
import '../widgets/doodle_editor_sheet.dart';
import '../widgets/doodle_painter.dart';
import '../widgets/month_calendar.dart';
import '../widgets/week_calendar.dart';
import 'settings_page.dart';

enum CalendarView { month, week, flow }

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
  final PaperSoundService _paperSoundService = PaperSoundService();
  bool _loading = true;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<Uri>? _notificationClickSubscription;
  bool _widgetEditorPending = false;
  bool _openingWidgetEditor = false;
  bool _sharing = false;
  _SaveFlight? _saveFlight;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  Future<void> _loadDoodles() async {
    final doodles = await widget.repository.loadAll();
    if (!mounted) return;
    setState(() {
      _doodles = doodles;
      _loading = false;
    });
    final notificationLaunchUri = await widget.reminderService
        .takeInitialLaunchUri();
    if (!mounted) return;
    _handleEditorLaunch(notificationLaunchUri);
    _scheduleTodayWidgetSync();
    _openPendingWidgetEditor();
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
      doodle: _doodles[dateKey(_today)],
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

  bool get _canUseLeftArrow =>
      _view == CalendarView.flow ? _canMoveForward : _canMoveBack;

  bool get _canUseRightArrow =>
      _view == CalendarView.flow ? _canMoveBack : _canMoveForward;

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
      if (direction > 0 && !_canMoveBack) return;
      if (direction < 0 && !_canMoveForward) return;
      _selectionHaptic();
      setState(() {
        _focusDate = _focusDate.subtract(Duration(days: direction));
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

  Future<void> _editDay(DateTime date, [Rect? targetRect]) async {
    if (isAfterDay(date, _today)) return;
    _lightHaptic();
    final key = dateKey(date);
    final result = await showDoodleEditor(
      context: context,
      date: date,
      initialDoodle: _doodles[key],
      hapticsEnabled: widget.settings.hapticsEnabled,
      language: widget.settings.language,
    );
    if (result == null || !mounted) return;
    final previousDoodle = _doodles[key];
    final resultDoodle = result.doodle;

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
    setState(() => _doodles = <String, Doodle>{});
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
      showDragHandle: true,
      builder: (context) => _StoryShareSheet(strings: _s),
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
        ),
        StoryShareFormat.todaySquare => StoryShareService.renderTodaySquare(
          doodle: todayDoodle!,
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
      'doodles': _doodles.map((key, doodle) => MapEntry(key, doodle.toJson())),
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
      setState(() => _doodles = restoredDoodles);
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
    const paperColor = Color(0xFFF7F3E8);
    return Theme(
      data: handwrittenTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: paperColor,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
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
                  painter: const _PaperTexturePainter(),
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.paddingOf(context).top),
                      const SizedBox(height: 50, child: _TopSpiral()),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 7),
                        child: _CalendarAppBar(
                          onShare: _sharing ? null : _openStoryShare,
                          onSettings: _openSettings,
                          strings: _s,
                          foregroundColor: const Color(0xFF173F32),
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
                          return _CalendarPeriodBar(
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
    required this.onSettings,
    required this.strings,
    required this.foregroundColor,
  });

  final VoidCallback? onShare;
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
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F3E8),
    );
    final speckle = Paint()
      ..color = const Color(0xFF6B6254).withValues(alpha: 0.035);
    for (var y = 9.0; y < size.height; y += 17) {
      for (var x = 7.0; x < size.width; x += 19) {
        final offset = ((x * 3 + y * 5).toInt() % 7) - 3;
        canvas.drawCircle(Offset(x + offset, y), 0.55, speckle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StoryShareSheet extends StatelessWidget {
  const _StoryShareSheet({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(
                strings.shareDrawing,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _StoryShareOption(
              key: const Key('share-month-story'),
              icon: Icons.grid_view_rounded,
              title: strings.monthStory,
              subtitle: strings.monthStorySubtitle,
              onTap: () =>
                  Navigator.of(context).pop(StoryShareFormat.monthGrid),
            ),
            const SizedBox(height: 8),
            _StoryShareOption(
              key: const Key('share-today-square'),
              icon: Icons.crop_square_rounded,
              title: strings.todaySquare,
              subtitle: strings.todaySquareSubtitle,
              onTap: () =>
                  Navigator.of(context).pop(StoryShareFormat.todaySquare),
            ),
            const SizedBox(height: 8),
            _StoryShareOption(
              key: const Key('share-recent-week'),
              icon: Icons.view_module_rounded,
              title: strings.recentWeekStory,
              subtitle: strings.recentWeekStorySubtitle,
              onTap: () =>
                  Navigator.of(context).pop(StoryShareFormat.recentWeek),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryShareOption extends StatelessWidget {
  const _StoryShareOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(icon, color: colors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
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
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          key: const Key('calendar-bottom-bar'),
          width: 286,
          child: Material(
            color: const Color(0xFFFFFEFA),
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
                        : const Color(0xFF626862),
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
                        : const Color(0xFF626862),
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
