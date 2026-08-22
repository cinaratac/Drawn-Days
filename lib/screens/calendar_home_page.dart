import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import '../services/today_home_widget_service.dart';
import '../utils/calendar_utils.dart';
import '../widgets/day_flow.dart';
import '../widgets/doodle_editor_sheet.dart';
import '../widgets/month_calendar.dart';
import '../widgets/week_calendar.dart';
import 'settings_page.dart';

enum DairryView { month, week, flow }

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({
    super.key,
    required this.repository,
    required this.settings,
    required this.onSettingsChanged,
    this.today,
  });

  final DoodleRepository repository;
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
  late DairryView _view;
  int _todayRequest = 0;
  Map<String, Doodle> _doodles = <String, Doodle>{};
  bool _loading = true;
  final GlobalKey _exportBoundaryKey = GlobalKey();
  StreamSubscription<Uri?>? _widgetClickSubscription;
  bool _widgetEditorPending = false;
  bool _openingWidgetEditor = false;

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
      StartViewPreference.month => DairryView.month,
      StartViewPreference.week => DairryView.week,
      StartViewPreference.flow => DairryView.flow,
    };
    _visibleMonth = ValueNotifier<DateTime>(_today);
    _initializeHomeWidgetLink();
    _loadDoodles();
  }

  @override
  void didUpdateWidget(covariant CalendarHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.language != widget.settings.language && !_loading) {
      _syncTodayWidget();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSubscription?.cancel();
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
    await _syncTodayWidget();
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

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'dairry' ||
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
    if (!_loading) unawaited(_syncTodayWidget());
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
  }

  Future<void> _syncTodayWidget() {
    return TodayHomeWidgetService.sync(
      date: _today,
      doodle: _doodles[dateKey(_today)],
      language: widget.settings.language,
    );
  }

  bool get _canMoveForward {
    return switch (_view) {
      DairryView.month => true,
      DairryView.week => !startOfWeek(
        _focusDate,
        mondayFirst: _mondayFirst,
      ).add(const Duration(days: 7)).isAfter(_today),
      DairryView.flow => dateOnly(_focusDate).isBefore(_today),
    };
  }

  bool get _canMoveBack => switch (_view) {
    DairryView.flow => _today.difference(dateOnly(_focusDate)).inDays < 3649,
    _ => true,
  };

  bool get _canUseLeftArrow =>
      _view == DairryView.flow ? _canMoveForward : _canMoveBack;

  bool get _canUseRightArrow =>
      _view == DairryView.flow ? _canMoveBack : _canMoveForward;

  void _selectionHaptic() {
    if (widget.settings.hapticsEnabled) HapticFeedback.selectionClick();
  }

  void _lightHaptic() {
    if (widget.settings.hapticsEnabled) HapticFeedback.lightImpact();
  }

  void _selectView(DairryView view) {
    if (_view == view) return;
    _selectionHaptic();
    setState(() {
      _view = view;
      if (view == DairryView.flow && isAfterDay(_focusDate, _today)) {
        _focusDate = _today;
      }
    });
    if (view == DairryView.month) _setVisibleMonth(_focusDate);
  }

  void _movePeriod(int direction) {
    if (_view == DairryView.flow) {
      if (direction > 0 && !_canMoveBack) return;
      if (direction < 0 && !_canMoveForward) return;
      _selectionHaptic();
      setState(() {
        _focusDate = _focusDate.subtract(Duration(days: direction));
      });
      return;
    }

    if (_view == DairryView.month) {
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
    final monthIsVisible = _view == DairryView.month;
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
    if (_view != DairryView.flow || isSameDay(date, _focusDate)) return;
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
      if (isSameDay(date, _today)) await _syncTodayWidget();
      return;
    }

    await widget.repository.save(key, result);
    if (!mounted) return;
    setState(() => _doodles[key] = result);
    if (isSameDay(date, _today)) await _syncTodayWidget();
  }

  Future<void> _clearDoodles() async {
    await widget.repository.clearAll();
    if (!mounted) return;
    setState(() => _doodles = <String, Doodle>{});
    await _syncTodayWidget();
  }

  Rect _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Rect.fromLTWH(0, 0, 1, 1);
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportCalendar() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _exportBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('Calendar is not ready');
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Calendar image could not be created');
    final bytes = data.buffer.asUint8List();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: ['dairry-calendar.png'],
        sharePositionOrigin: _shareOrigin(),
      ),
    );
  }

  Future<void> _createBackup() async {
    final encoded = jsonEncode(<String, Object?>{
      'format': 'dairry-backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'settings': widget.settings.toJson(),
      'doodles': _doodles.map((key, doodle) => MapEntry(key, doodle.toJson())),
    });
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['dairry-${dateKey(_today)}.dairry'],
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
      if (decoded is! Map || decoded['format'] != 'dairry-backup') {
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
      );
      final settingsApplied = await widget.onSettingsChanged(restoredSettings);
      if (!settingsApplied) return false;
      await widget.repository.replaceAll(restoredDoodles);
      if (!mounted) return true;
      setState(() => _doodles = restoredDoodles);
      await _syncTodayWidget();
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
          onExportCalendar: _exportCalendar,
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
        MonthCalendar(
          key: const ValueKey('month-pages'),
          month: _focusDate,
          today: _today,
          todayRequest: _todayRequest,
          isActive: _view == DairryView.month,
          doodles: _doodles,
          onDayTap: _editDay,
          onVisibleMonthChanged: _setVisibleMonth,
          onMonthChanged: _changeMonth,
          language: widget.settings.language,
          mondayFirst: _mondayFirst,
        ),
        WeekCalendar(
          key: const ValueKey('week-pages'),
          focusDate: _focusDate,
          today: _today,
          todayRequest: _todayRequest,
          isActive: _view == DairryView.week,
          doodles: _doodles,
          onDayTap: _editDay,
          language: widget.settings.language,
          mondayFirst: _mondayFirst,
        ),
        DayFlow(
          key: const ValueKey('day-flow'),
          today: _today,
          focusDate: _focusDate,
          todayRequest: _todayRequest,
          isActive: _view == DairryView.flow,
          doodles: _doodles,
          onDayTap: _editDay,
          onVisibleDateChanged: _changeFlowDate,
          language: widget.settings.language,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: DairryBottomNavigation(
        selected: _view,
        onSelected: _selectView,
        strings: _s,
      ),
      body: RepaintBoundary(
        key: _exportBoundaryKey,
        child: ColoredBox(
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
                      onSettings: _openSettings,
                      onBack: _canUseLeftArrow ? () => _movePeriod(-1) : null,
                      onForward: _canUseRightArrow
                          ? () => _movePeriod(1)
                          : null,
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
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget {
  const _CalendarAppBar({
    required this.onToday,
    required this.onSettings,
    required this.onBack,
    required this.onForward,
    required this.strings,
  });

  final VoidCallback onToday;
  final VoidCallback onSettings;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'dairry.',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 18, letterSpacing: -0.4),
        ),
        const SizedBox(width: 9),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          key: const Key('open-settings'),
          tooltip: strings.settings,
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded, size: 20),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        TextButton.icon(
          key: const Key('go-today'),
          onPressed: onToday,
          icon: const Icon(Icons.near_me_outlined, size: 17),
          label: Text(strings.today),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        const Spacer(),
        if (onBack != null)
          _NavigationButton(
            key: const Key('previous-period'),
            icon: Icons.chevron_left_rounded,
            onTap: onBack,
          ),
        const SizedBox(width: 7),
        if (onForward != null)
          _NavigationButton(
            key: const Key('next-period'),
            icon: Icons.chevron_right_rounded,
            onTap: onForward,
          )
        else
          const SizedBox(width: 40, height: 40),
      ],
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

class DairryBottomNavigation extends StatelessWidget {
  const DairryBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.strings,
  });

  final DairryView selected;
  final ValueChanged<DairryView> onSelected;
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
          clipBehavior: Clip.antiAlias,
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
                  onSelected(DairryView.values[index]),
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
