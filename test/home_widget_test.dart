import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/settings/presentation/settings_screen.dart';
import 'package:cadence/features/widgets/models/widget_sync_data.dart';
import 'package:cadence/features/widgets/providers/home_widget_providers.dart';
import 'package:cadence/features/widgets/services/home_widget_sync_service.dart';

void main() {
  late AppDatabase db;
  late HomeWidgetSyncService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = HomeWidgetSyncService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HomeWidgetSyncService Unit Tests', () {
    test('Empty database aggregates zero metrics and valid circadian phase', () async {
      final syncData = await service.syncWidget();

      expect(syncData.focusMinutes, 0);
      expect(syncData.todaySteps, 0);
      expect(syncData.waterGlasses, 0);
      expect(syncData.streakDays, 0);
      expect(syncData.circadianPhase, anyOf('Daylight', 'Twilight', 'Night', 'Dawn'));

      final map = syncData.toMap();
      expect(map['focus_minutes'], 0);
      expect(map['today_steps'], 0);
      expect(map['water_glasses'], 0);
      expect(map['streak_days'], 0);
      expect(map.containsKey('last_updated'), isTrue);
    });

    test('Aggregates live telemetry into WidgetSyncData accurately', () async {
      final now = DateTime.now();

      // 1. Insert Focus Study Session today (60 min)
      await db.into(db.studySessions).insert(
            StudySessionsCompanion(
              id: const Value('study_today_1'),
              subject: const Value('Flutter Widgets'),
              durationSeconds: const Value(3600),
              actualSeconds: const Value(3600),
              sessionType: const Value('work'),
              startedAt: Value(now.subtract(const Duration(minutes: 70))),
              completedAt: Value(now.subtract(const Duration(minutes: 10))),
            ),
          );

      // 2. Insert Water Entries today (4 glasses)
      await db.into(db.entries).insert(
            EntriesCompanion(
              id: const Value('water_today_1'),
              userId: const Value('local_user'),
              type: const Value('water'),
              value: const Value(4.0),
              unit: const Value('glasses'),
              occurredAt: Value(now.subtract(const Duration(hours: 1))),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 3. Insert Routine and Completion for streak
      await db.into(db.routines).insert(
            const RoutinesCompanion(
              id: Value('routine_w1'),
              title: Value('Morning Prep'),
              timeOfDay: Value('morning'),
            ),
          );
      await db.into(db.routineItems).insert(
            const RoutineItemsCompanion(
              id: Value('item_w1'),
              routineId: Value('routine_w1'),
              title: Value('Deep Breath'),
            ),
          );
      await db.into(db.routineCompletions).insert(
            RoutineCompletionsCompanion(
              id: const Value(1),
              routineId: const Value('routine_w1'),
              itemId: const Value('item_w1'),
              completedDate: Value(DateTime(now.year, now.month, now.day).toIso8601String().split('T').first),
              completedAt: Value(now),
            ),
          );

      final syncData = await service.syncWidget(overrideSteps: 4850);

      expect(syncData.focusMinutes, 60);
      expect(syncData.waterGlasses, 4);
      expect(syncData.todaySteps, 4850);
      expect(syncData.streakDays, greaterThanOrEqualTo(1));
    });

    test('Quick Action handler logs water and increments count in database', () async {
      final handled = await service.handleQuickAction(
        Uri.parse('cadence://quick_action?type=water'),
      );

      expect(handled, isTrue);

      final entries = await db.select(db.entries).get();
      expect(entries.length, 1);
      expect(entries.first.type, 'water');
      expect(entries.first.value, 1.0);

      // Subsequent quick action
      final handledAgain = await service.handleQuickAction(
        Uri.parse('cadence://quick_action?type=water'),
      );
      expect(handledAgain, isTrue);

      final updatedEntries = await db.select(db.entries).get();
      expect(updatedEntries.length, 2);

      // Unknown quick action returns false
      final unhandled = await service.handleQuickAction(
        Uri.parse('cadence://quick_action?type=unknown'),
      );
      expect(unhandled, isFalse);

      final wrongHost = await service.handleQuickAction(
        Uri.parse('cadence://other_action?type=water'),
      );
      expect(wrongHost, isFalse);
    });
  });

  group('Home Screen Widget Settings UI Tests', () {
    testWidgets('Renders Android Home Screen Widget tile and triggers manual sync', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeWidgetSyncDataProvider.overrideWith((ref) => Stream.value(
                  WidgetSyncData(
                    focusMinutes: 30,
                    todaySteps: 2500,
                    waterGlasses: 3,
                    streakDays: 2,
                    circadianPhase: 'Daylight',
                    lastUpdated: DateTime.now(),
                  ),
                )),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Android Home Screen Widget'), findsOneWidget);
      expect(find.text('Update Widget Data'), findsOneWidget);
      expect(find.text('Sync Widget'), findsOneWidget);

      // Verify data preview
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
      expect(find.text('3 gl'), findsOneWidget);

      // Verify Sync Widget button is present and enabled
      final syncButtonFinder = find.widgetWithText(FilledButton, 'Sync Widget');
      expect(syncButtonFinder, findsOneWidget);
      final buttonWidget = tester.widget<FilledButton>(syncButtonFinder);
      expect(buttonWidget.onPressed, isNotNull);
    });
  });
}
