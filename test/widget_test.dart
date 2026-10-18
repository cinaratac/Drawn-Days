import 'dart:async';

import 'package:drawn_days/data/doodle_repository.dart';
import 'package:drawn_days/data/settings_repository.dart';
import 'package:drawn_days/main.dart';
import 'package:drawn_days/models/app_settings.dart';
import 'package:drawn_days/screens/onboarding_page.dart';
import 'package:drawn_days/screens/settings_page.dart';
import 'package:drawn_days/services/app_review_service.dart';
import 'package:drawn_days/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 8, 21);
  const completedOnboardingSettings = AppSettings(
    language: AppLanguage.turkish,
    onboardingCompleted: true,
  );

  Future<void> usePhoneSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> drawOnDay(WidgetTester tester, String dateKey) async {
    await tester.tap(find.byKey(Key('day-$dateKey')));
    await tester.pumpAndSettle();

    final canvas = find.byKey(const Key('doodle-canvas'));
    final canvasRect = tester.getRect(canvas);
    await tester.dragFrom(
      canvasRect.centerLeft + const Offset(24, 0),
      const Offset(64, 34),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-doodle')));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the current month and keeps future days read-only', (
    tester,
  ) async {
    await usePhoneSize(tester);
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: MemoryDoodleRepository(),
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ağustos'), findsWidgets);
    expect(find.text('Ay'), findsOneWidget);
    expect(find.text('Hafta'), findsOneWidget);
    expect(find.text('Gün gün'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('calendar-bottom-bar'))).width,
      286,
    );
    expect(find.byKey(const Key('today-empty-highlight')), findsOneWidget);
    expect(find.byKey(const Key('you-are-here-marker')), findsNothing);

    final mondayCell = tester.getRect(find.byKey(const Key('day-2026-08-03')));
    final sundayCell = tester.getRect(find.byKey(const Key('day-2026-08-02')));
    expect(mondayCell.left, closeTo(2, 0.5));
    expect(393 - sundayCell.right, closeTo(2, 0.5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('month-pages')),
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('day-2026-08-22')));
    await tester.pumpAndSettle();

    expect(find.text('O gün neye benziyordu?'), findsNothing);
    expect(find.text('Bu gün henüz yaşanmadı.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('day-2026-08-21')));
    await tester.pumpAndSettle();

    expect(find.text('O gün neye benziyordu?'), findsOneWidget);
    expect(find.byKey(const Key('doodle-editor-page')), findsOneWidget);
  });

  testWidgets('draws and persists a doodle for a day', (tester) async {
    await usePhoneSize(tester);
    final repository = MemoryDoodleRepository();
    final reminderService = RecordingReminderService();
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: repository,
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        reminderService: reminderService,
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-2026-08-21')));
    await tester.pumpAndSettle();

    final canvas = find.byKey(const Key('doodle-canvas'));
    final canvasRect = tester.getRect(canvas);
    expect(canvasRect.width, closeTo(canvasRect.height, 0.01));
    await tester.dragFrom(
      canvasRect.topCenter + const Offset(0, 24),
      Offset(0, canvasRect.height - 48),
    );
    await tester.pump();
    expect(find.text('O gün neye benziyordu?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-doodle')));
    await tester.pumpAndSettle();

    final saved = await repository.loadAll();
    expect(saved['2026-08-21'], isNotNull);
    expect(saved['2026-08-21']!.strokes, isNotEmpty);
    expect(reminderService.updatedDate, today);
    expect(reminderService.hasDoodle, isTrue);
    expect(find.text('O gün neye benziyordu?'), findsNothing);
    expect(find.byKey(const Key('today-empty-highlight')), findsNothing);
    expect(find.byKey(const Key('you-are-here-marker')), findsOneWidget);
  });

  testWidgets('opens and persists a month drawing separately', (tester) async {
    await usePhoneSize(tester);
    final repository = MemoryDoodleRepository();
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: repository,
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('month-drawing-toggle')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('month-drawing-panel')), findsOneWidget);
    expect(find.byKey(const Key('fixed-month-drawing-mode')), findsOneWidget);

    final gridSurfaceRect = tester.getRect(
      find.byKey(const Key('month-grid-drawing-surface')),
    );
    final joinedCanvasRect = tester.getRect(
      find.byKey(const Key('month-drawing-canvas')),
    );
    final headerSurfaceRect = tester.getRect(
      find.byKey(const Key('month-header-drawing-surface')),
    );
    final joinedStart = Offset(
      headerSurfaceRect.center.dx,
      headerSurfaceRect.center.dy,
    );
    final joinedGesture = await tester.startGesture(joinedStart);
    await joinedGesture.moveTo(
      Offset(gridSurfaceRect.center.dx, gridSurfaceRect.top + 24),
    );
    await joinedGesture.moveTo(
      Offset(gridSurfaceRect.center.dx + 10, gridSurfaceRect.bottom - 24),
    );
    await joinedGesture.moveTo(
      Offset(joinedCanvasRect.center.dx + 20, joinedCanvasRect.top + 42),
    );
    await joinedGesture.up();
    await tester.pumpAndSettle();

    var saved = await repository.loadAll();
    expect(
      saved['month-header:2026-08-01']!.strokes.last.points.last.dy,
      closeTo(1, .0001),
    );
    expect(
      saved['month-grid:2026-08-01']!.strokes.last.points.first.dy,
      closeTo(0, .0001),
    );
    expect(
      saved['month-canvas:2026-08-01']!.strokes.first.points.first.dy,
      closeTo(0, .0001),
    );

    final undo = find.byKey(const Key('month-drawing-undo'));
    await tester.ensureVisible(undo);
    await tester.pumpAndSettle();
    await tester.tap(undo);
    await tester.pumpAndSettle();
    saved = await repository.loadAll();
    expect(saved['month-header:2026-08-01'], isNull);
    expect(saved['month-grid:2026-08-01'], isNull);
    expect(saved['month-canvas:2026-08-01'], isNull);

    final thickBrush = find.byKey(const Key('month-brush-10.5'));
    await tester.ensureVisible(thickBrush);
    await tester.pumpAndSettle();
    await tester.tap(thickBrush);
    await tester.pump();
    final canvas = find.byKey(const Key('month-drawing-canvas'));
    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();
    final canvasRect = tester.getRect(canvas);
    await tester.dragFrom(
      canvasRect.centerLeft + const Offset(30, 0),
      const Offset(100, 35),
    );
    await tester.pumpAndSettle();

    saved = await repository.loadAll();
    expect(saved['month-header:2026-08-01'], isNull);
    expect(saved['month-grid:2026-08-01'], isNull);
    expect(saved['month-canvas:2026-08-01'], isNotNull);
    expect(saved['month-canvas:2026-08-01']!.strokes, isNotEmpty);
    expect(saved['month-canvas:2026-08-01']!.strokes.last.width, 10.5);
    expect(saved['2026-08-01'], isNull);

    final clear = find.byKey(const Key('month-drawing-clear'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    saved = await repository.loadAll();
    expect(saved['month-header:2026-08-01'], isNull);
    expect(saved['month-grid:2026-08-01'], isNull);
    expect(saved['month-canvas:2026-08-01'], isNull);

    final fixedMode = find.byKey(const Key('fixed-month-drawing-mode'));
    final modePositionBefore = tester.getTopLeft(fixedMode);
    await tester.drag(fixedMode, const Offset(-72, -54));
    await tester.pumpAndSettle();
    final modePositionAfter = tester.getTopLeft(fixedMode);
    expect(modePositionAfter.dx, lessThan(modePositionBefore.dx));
    expect(modePositionAfter.dy, lessThan(modePositionBefore.dy));
    await tester.tap(fixedMode);
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(196, 500), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(fixedMode.hitTestable(), findsOneWidget);
    await tester.tap(fixedMode);
    await tester.pumpAndSettle();
  });

  testWidgets('requests a store review after a few saved doodles', (
    tester,
  ) async {
    await usePhoneSize(tester);
    final appReviewService = MemoryAppReviewService();
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: MemoryDoodleRepository(),
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        appReviewService: appReviewService,
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    await drawOnDay(tester, '2026-08-19');
    await drawOnDay(tester, '2026-08-20');
    expect(appReviewService.requestReviewCount, 0);

    await drawOnDay(tester, '2026-08-21');
    expect(appReviewService.requestReviewCount, 1);
  });

  testWidgets('moves between months from the period header', (tester) async {
    await usePhoneSize(tester);
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: MemoryDoodleRepository(),
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previous-period')));
    await tester.pumpAndSettle();

    expect(find.text('Temmuz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-period')));
    await tester.pumpAndSettle();

    expect(find.text('Ağustos'), findsWidgets);
  });

  testWidgets('notification opens today drawing editor', (tester) async {
    await usePhoneSize(tester);
    final reminderService = RecordingReminderService(
      initialLaunchUri: Uri.parse(
        'drawndays://draw/today?reminderDate=2026-08-21',
      ),
    );
    addTearDown(reminderService.close);
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: MemoryDoodleRepository(),
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        reminderService: reminderService,
        today: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(reminderService.initialLaunchUri, isNull);
    expect(find.byKey(const Key('doodle-editor-page')), findsOneWidget);
    expect(find.text('O gün neye benziyordu?'), findsOneWidget);
  });

  testWidgets('switches between month, week and flow on one page', (
    tester,
  ) async {
    await usePhoneSize(tester);
    await tester.pumpWidget(
      DrawnDaysApp(
        repository: MemoryDoodleRepository(),
        settingsRepository: MemorySettingsRepository(
          completedOnboardingSettings,
        ),
        today: today,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-navigation-brush')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-week')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-2026-08-17')), findsOneWidget);
    expect(find.byKey(const Key('selected-navigation-brush')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-flow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-flow')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-month')));
    await tester.pumpAndSettle();
    expect(find.text('Ağustos'), findsWidgets);
  });

  testWidgets('prevents overlapping settings updates', (tester) async {
    await usePhoneSize(tester);
    final releaseUpdate = Completer<bool>();
    var updateCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          settings: completedOnboardingSettings,
          doodleCount: 0,
          onSettingsChanged: (_) {
            updateCount++;
            return releaseUpdate.future;
          },
          onClearDoodles: () async {},
          onCreateBackup: () async {},
          onRestoreBackup: () async => false,
          onRateApp: () async {},
          showRateApp: false,
        ),
      ),
    );

    final soundSwitch = find.widgetWithText(SwitchListTile, 'Ses');
    await tester.tap(soundSwitch);
    await tester.pump();

    expect(updateCount, 1);
    final vibrationSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Titreşim'),
    );
    expect(vibrationSwitch.onChanged, isNull);

    releaseUpdate.complete(true);
    await tester.pumpAndSettle();

    final enabledVibrationSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Titreşim'),
    );
    expect(enabledVibrationSwitch.onChanged, isNotNull);
  });

  testWidgets('onboarding has three working pages', (tester) async {
    await usePhoneSize(tester);
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          onStart: () async {
            started = true;
            return false;
          },
        ),
      ),
    );

    expect(find.text('One day, one little drawing.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byKey(const Key('skip-onboarding')), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-guide-page')));
    await tester.pumpAndSettle();
    expect(find.text('Tap a day. Draw how it felt.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-guide-page')));
    await tester.pumpAndSettle();
    expect(find.text('Your month, in your own marks.'), findsOneWidget);
    expect(find.byKey(const Key('start-app')), findsOneWidget);
    expect(find.byKey(const Key('skip-onboarding')), findsNothing);

    await tester.tap(find.byKey(const Key('start-app')));
    await tester.pumpAndSettle();
    expect(started, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding fits a compact phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onStart: () async => false)),
    );

    for (var page = 0; page < 3; page++) {
      expect(tester.takeException(), isNull, reason: 'onboarding page $page');
      if (page < 2) {
        await tester.tap(find.byKey(const Key('next-guide-page')));
        await tester.pumpAndSettle();
      }
    }
  });
}

class RecordingReminderService extends MemoryReminderService {
  RecordingReminderService({this.initialLaunchUri});

  final StreamController<Uri> _launchController =
      StreamController<Uri>.broadcast(sync: true);
  Uri? initialLaunchUri;
  DateTime? updatedDate;
  bool? hasDoodle;

  @override
  Stream<Uri> get launchUris => _launchController.stream;

  @override
  Future<Uri?> takeInitialLaunchUri() async {
    final uri = initialLaunchUri;
    initialLaunchUri = null;
    return uri;
  }

  void openToday() {
    _launchController.add(Uri.parse('drawndays://draw/today?notification'));
  }

  Future<void> close() => _launchController.close();

  @override
  Future<void> updateDate({
    required DateTime date,
    required bool hasDoodle,
    required AppSettings settings,
  }) async {
    updatedDate = date;
    this.hasDoodle = hasDoodle;
  }
}
