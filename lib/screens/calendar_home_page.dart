import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../data/doodle_repository.dart';
import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/doodle.dart';
import '../services/reminder_service.dart';
import '../services/story_share_service.dart';
import '../services/today_home_widget_service.dart';
import '../utils/calendar_utils.dart';
import '../widgets/day_flow.dart';
import '../widgets/doodle_editor_sheet.dart';
import '../widgets/month_calendar.dart';
import '../widgets/week_calendar.dart';
import 'settings_page.dart';

enum CalendarView { month, week, flow }

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({
    super.key,
    required this.repository,
    required this.reminderService,
    required this.settings,
    required this.onSettingsChanged,
    this.today,
  });

  final DoodleRepository repository;
  final ReminderService reminderService;
  final AppSettings settings;
  final Future<bool> Function(AppSettings settings) onSettingsChanged;
  final DateTime? today;

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage>
    with WidgetsBindingObserver {
  late DateTime _today;
  late DateTime _focusDate;
  late final ValueNotifier<DateTime> _visibleMonth;
  late CalendarView _view;
  int _todayRequest = 0;
  Map<String, Doodle> _doodles = <String, Doodle>{};
  bool _loading = true;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<Uri>? _notificationClickSubscription;
  bool _widgetEditorPending = false;
  bool _openingWidgetEditor = false;
  bool _sharing = false;

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

  Future<void> _editDay(DateTime date) async {
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

    if (result.isEmpty) {
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

    await widget.repository.save(key, result);
    if (!mounted) return;
    setState(() => _doodles[key] = result);
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
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: CalendarBottomNavigation(
        selected: _view,
        onSelected: _selectView,
        strings: _s,
      ),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _CalendarAppBar(
                    onToday: _goToToday,
                    onShare: _sharing ? null : _openStoryShare,
                    onSettings: _openSettings,
                    onBack: _canUseLeftArrow ? () => _movePeriod(-1) : null,
                    onForward: _canUseRightArrow ? () => _movePeriod(1) : null,
                    strings: _s,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _buildCalendarViews(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget {
  const _CalendarAppBar({
    required this.onToday,
    required this.onShare,
    required this.onSettings,
    required this.onBack,
    required this.onForward,
    required this.strings,
  });

  final VoidCallback onToday;
  final VoidCallback? onShare;
  final VoidCallback onSettings;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        return Row(
          children: [
            SizedBox(
              width: compact ? 108 : 120,
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Drawn Days',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: compact ? 2 : 4),
            SizedBox(
              width: compact ? 38 : 44,
              height: 40,
              child: IconButton(
                key: const Key('open-settings'),
                tooltip: strings.settings,
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(
              width: compact ? 68 : 82,
              height: 40,
              child: TextButton.icon(
                key: const Key('go-today'),
                onPressed: onToday,
                icon: Icon(Icons.near_me_outlined, size: compact ? 16 : 17),
                label: Text(
                  strings.today,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            SizedBox(
              width: compact ? 38 : 40,
              height: 40,
              child: IconButton(
                key: const Key('share-story'),
                tooltip: strings.share,
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                constraints: BoxConstraints.tightFor(
                  width: compact ? 38 : 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const Spacer(),
            _NavigationButton(
              key: const Key('previous-period'),
              icon: Icons.chevron_left_rounded,
              onTap: onBack,
            ),
            SizedBox(width: compact ? 2 : 7),
            _NavigationButton(
              key: const Key('next-period'),
              icon: Icons.chevron_right_rounded,
              onTap: onForward,
            ),
          ],
        );
      },
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: onTap == null ? colors.surfaceContainerHighest : colors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: onTap == null
                ? colors.onSurfaceVariant.withValues(alpha: 0.45)
                : colors.onSurface,
          ),
        ),
      ),
    );
  }
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
        child: Material(
          color: Colors.white,
          elevation: 5,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(24),
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
              height: 66,
              animationDuration: Duration.zero,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              indicatorColor: colors.primary.withValues(alpha: 0.16),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                return TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? colors.primary
                      : const Color(0xFF626862),
                  fontSize: 12,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w600,
                );
              }),
              selectedIndex: selected.index,
              onDestinationSelected: (index) =>
                  onSelected(CalendarView.values[index]),
              destinations: [
                NavigationDestination(
                  key: const Key('view-month'),
                  icon: const Icon(Icons.calendar_view_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_view_month_rounded),
                  label: strings.month,
                ),
                NavigationDestination(
                  key: const Key('view-week'),
                  icon: const Icon(Icons.view_week_outlined),
                  selectedIcon: const Icon(Icons.view_week_rounded),
                  label: strings.week,
                ),
                NavigationDestination(
                  key: const Key('view-flow'),
                  icon: const Icon(Icons.auto_stories_outlined),
                  selectedIcon: const Icon(Icons.auto_stories_rounded),
                  label: strings.flow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
