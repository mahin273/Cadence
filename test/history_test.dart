import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/features/history/models/day_history_models.dart';
import 'package:cadence/features/history/services/history_timeline_service.dart';
import 'package:cadence/features/history/presentation/day_history_screen.dart';
import 'package:cadence/features/history/presentation/universal_search_screen.dart';
import 'package:cadence/features/history/providers/history_providers.dart';

void main() {
  late AppDatabase db;
  late HistoryTimelineService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = HistoryTimelineService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HistoryTimelineService Unit Tests', () {
    test('Empty database returns empty summary and zero events for any day', () async {
      final targetDate = DateTime(2026, 3, 15);
      final history = await service.getDayHistory(targetDate);

      expect(history.date, targetDate);
      expect(history.events, isEmpty);
      expect(history.totalStudyMinutes, 0);
      expect(history.totalExpenses, 0.0);
      expect(history.routinesCompletedCount, 0);
      expect(history.totalWaterGlasses, 0.0);
      expect(history.totalMovementDistanceMeters, 0.0);
    });

    test('getDayHistory aggregates and sorts events across all domains chronologically', () async {
      final targetDate = DateTime(2026, 3, 15);

      // 1. Water at 08:00
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w_1',
              userId: 'u1',
              type: 'water',
              value: 3.0,
              occurredAt: targetDate.add(const Duration(hours: 8)),
            ),
          );

      // 2. Study Session at 10:00 - 11:30 (5400 sec = 90 min)
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's_1',
              subject: 'Advanced Algorithms',
              durationSeconds: 3600,
              actualSeconds: 5400,
              startedAt: targetDate.add(const Duration(hours: 10)),
              completedAt: Value(targetDate.add(const Duration(hours: 11, minutes: 30))),
              sessionType: 'work',
            ),
          );

      // 3. Expense at 12:30 ($18.50)
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: 'exp_1',
              userId: 'u1',
              amount: 18.50,
              category: 'Food',
              note: const Value('Lunch Bowl'),
              occurredAt: targetDate.add(const Duration(hours: 12, minutes: 30)),
            ),
          );

      // 4. Outdoor Route at 17:00 (4200m)
      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'r_1',
              title: const Value('Park Run'),
              startTime: targetDate.add(const Duration(hours: 17)),
              totalDistanceMeters: const Value(4200.0),
              durationSeconds: const Value(1500),
            ),
          );

      final history = await service.getDayHistory(targetDate);

      expect(history.date, targetDate);
      expect(history.events.length, 4);

      // Verify sorted chronologically
      expect(history.events[0].eventType, TimelineEventType.water);
      expect(history.events[0].title, 'Water Intake');
      expect(history.events[0].timestamp.hour, 8);

      expect(history.events[1].eventType, TimelineEventType.study);
      expect(history.events[1].title, 'Focus: Advanced Algorithms');
      expect(history.events[1].timestamp.hour, 10);

      expect(history.events[2].eventType, TimelineEventType.expense);
      expect(history.events[2].title, 'Expense: Food');
      expect(history.events[2].subtitle, 'Lunch Bowl');
      expect(history.events[2].timestamp.hour, 12);

      expect(history.events[3].eventType, TimelineEventType.movement);
      expect(history.events[3].title, 'Park Run');
      expect(history.events[3].timestamp.hour, 17);

      // Verify aggregated metrics
      expect(history.totalStudyMinutes, 90);
      expect(history.totalExpenses, 18.50);
      expect(history.totalWaterGlasses, 3.0);
      expect(history.totalMovementDistanceMeters, 4200.0);
    });

    test('searchAcrossAllDomains accurately queries expenses, sessions, and routes', () async {
      final now = DateTime(2026, 4, 1);

      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's_math',
              subject: 'Linear Algebra Review',
              durationSeconds: 1800,
              actualSeconds: 1800,
              startedAt: now,
              sessionType: 'work',
            ),
          );

      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: 'exp_book',
              userId: 'u1',
              amount: 65.0,
              category: 'Education',
              note: const Value('Linear Algebra Textbook'),
              occurredAt: now,
            ),
          );

      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: 'exp_coffee',
              userId: 'u1',
              amount: 4.5,
              category: 'Coffee',
              note: const Value('Espresso'),
              occurredAt: now,
            ),
          );

      // Search for "Linear"
      final results = await service.searchAcrossAllDomains('Linear');
      expect(results.length, 2);
      expect(results.any((r) => r.type == TimelineEventType.study && r.title.contains('Linear Algebra Review')), isTrue);
      expect(results.any((r) => r.type == TimelineEventType.expense && r.subtitle.contains('Linear Algebra Textbook')), isTrue);

      // Search for "Espresso"
      final coffeeResults = await service.searchAcrossAllDomains('Espresso');
      expect(coffeeResults.length, 1);
      expect(coffeeResults.first.type, TimelineEventType.expense);

      // Search for non-existent keyword
      final emptyResults = await service.searchAcrossAllDomains('NonExistentKeywordXYZ');
      expect(emptyResults, isEmpty);
    });
  });

  group('History Screens Widget Tests', () {
    testWidgets('DayHistoryScreen renders date selector, metrics, and timeline items', (tester) async {
      final targetDate = DateTime(2026, 3, 15);

      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's_ui',
              subject: 'Mobile Systems Design',
              durationSeconds: 3600,
              actualSeconds: 3600,
              startedAt: targetDate.add(const Duration(hours: 14)),
              sessionType: 'work',
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      container.read(selectedHistoryDateProvider.notifier).selectDate(targetDate);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DayHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Past Timeline & History'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Verify the study session is rendered
      expect(find.text('Focus: Mobile Systems Design'), findsOneWidget);
      expect(find.text('60m duration (work)'), findsOneWidget);
    });

    testWidgets('UniversalSearchScreen allows searching across domains and displays hits', (tester) async {
      await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              id: 't_ui',
              userId: 'u1',
              amount: 24.0,
              category: 'Software',
              note: const Value('Cloud Server Subscription'),
              occurredAt: DateTime(2026, 3, 15, 10, 0),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: UniversalSearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Cloud Server');
      await tester.pumpAndSettle();

      // Verify search result tile shows up
      expect(find.text(r'$24.00 - Software'), findsOneWidget);
      expect(find.textContaining('Cloud Server Subscription'), findsOneWidget);
    });
  });
}
