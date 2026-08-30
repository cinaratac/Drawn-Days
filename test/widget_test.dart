import 'dart:async';

import 'package:drawn_days/data/doodle_repository.dart';
import 'package:drawn_days/data/settings_repository.dart';
import 'package:drawn_days/main.dart';
import 'package:drawn_days/models/app_settings.dart';
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

  testWidgets('opens on the current month and locks future days', (
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

    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('Ay'), findsOneWidget);
    expect(find.text('Hafta'), findsOneWidget);
    expect(find.text('Akış'), findsOneWidget);

    await tester.tap(find.byKey(const Key('day-2026-08-22')));
    await tester.pumpAndSettle();

    expect(find.text('O gün neye benziyordu?'), findsNothing);

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

  testWidgets('swipes horizontally between months', (tester) async {
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

    await tester.fling(
      find.byKey(const Key('day-2026-08-10')),
      const Offset(280, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Temmuz 2026'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('day-2026-07-10')),
      const Offset(-280, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ağustos 2026'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('view-week')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-2026-08-17')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-flow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-flow')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-month')));
    await tester.pumpAndSettle();
    expect(find.text('Ağustos 2026'), findsOneWidget);
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
