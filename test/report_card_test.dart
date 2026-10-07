import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/reports/models/report_card_models.dart';
import 'package:cadence/features/reports/presentation/visual_report_card_screen.dart';
import 'package:cadence/features/reports/services/report_card_service.dart';

void main() {
  late AppDatabase db;
  late ReportCardService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = ReportCardService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ReportCardService Unit Tests', () {
    test('Empty database yields zero metrics and Needs Momentum grade', () async {
      final report = await service.generateReportCard(range: ReportCardTimeRange.week);

      expect(report.title, contains('Report Card'));
      expect(report.totalFocusMinutes, 0);
      expect(report.completedFocusSessions, 0);
      expect(report.totalMovementKm, 0.0);
      expect(report.completedRoutinesCount, 0);
      expect(report.totalExpenses, 0.0);
      expect(report.totalWaterGlasses, 0.0);
      expect(report.consistencyGrade, 'Needs Momentum');
      expect(report.activeDaysCount, 0);
    });

    test('Aggregates multi-domain telemetry accurately within time range', () async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      // 1. Insert Study Session
      await db.into(db.studySessions).insert(
            StudySessionsCompanion(
              id: const Value('study_1'),
              subject: const Value('System Design'),
              durationSeconds: const Value(5400),
              actualSeconds: const Value(5400), // 90 mins
              sessionType: const Value('work'),
              startedAt: Value(now.subtract(const Duration(hours: 4))),
              completedAt: Value(now.subtract(const Duration(hours: 2, minutes: 30))),
            ),
          );

      // 2. Insert Route
      await db.into(db.routes).insert(
            RoutesCompanion(
              id: const Value('route_1'),
              title: const Value('Morning Jog'),
              totalDistanceMeters: const Value(5400.0), // 5.4 km
              durationSeconds: const Value(1800),
              startTime: Value(now.subtract(const Duration(hours: 8))),
              endTime: Value(now.subtract(const Duration(hours: 7, minutes: 30))),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 3. Insert Routine, Routine Item & Completion
      await db.into(db.routines).insert(
            const RoutinesCompanion(
              id: Value('routine_1'),
              title: Value('Hydration & Reset'),
              timeOfDay: Value('morning'),
            ),
          );
      await db.into(db.routineItems).insert(
            const RoutineItemsCompanion(
              id: Value('item_1'),
              routineId: Value('routine_1'),
              title: Value('Drink 500ml water'),
            ),
          );
      await db.into(db.routineCompletions).insert(
            RoutineCompletionsCompanion(
              id: const Value(1),
              routineId: const Value('routine_1'),
              itemId: const Value('item_1'),
              completedDate: Value(todayDate.toIso8601String().split('T').first),
              completedAt: Value(now.subtract(const Duration(hours: 6))),
            ),
          );

      // 4. Insert Expense
      await db.into(db.expenses).insert(
            ExpensesCompanion(
              id: const Value('exp_1'),
              userId: const Value('local_user'),
              amount: const Value(42.50),
              category: const Value('Groceries'),
              occurredAt: Value(now.subtract(const Duration(hours: 2))),
              currency: const Value('USD'),
              note: const Value('Organic fruits, tea'),
              tags: const Value(['food', 'groceries']),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 5. Insert Water Entry
      await db.into(db.entries).insert(
            EntriesCompanion(
              id: const Value('entry_1'),
              userId: const Value('local_user'),
              type: const Value('water'),
              value: const Value(5.0), // 5 glasses
              unit: const Value('glasses'),
              occurredAt: Value(now.subtract(const Duration(hours: 1))),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final report = await service.generateReportCard(range: ReportCardTimeRange.week);

      expect(report.totalFocusMinutes, 90);
      expect(report.completedFocusSessions, 1);
      expect(report.totalMovementKm, closeTo(5.4, 0.01));
      expect(report.completedRoutinesCount, 1);
      expect(report.totalExpenses, closeTo(42.50, 0.01));
      expect(report.totalWaterGlasses, 5.0);
      expect(report.activeDaysCount, greaterThanOrEqualTo(1));
    });

    test('Grades consistency accurately according to active habits and momentum', () async {
      final now = DateTime.now();

      // Populate routine & item
      await db.into(db.routines).insert(
            const RoutinesCompanion(
              id: Value('routine_a'),
              title: Value('Evening Stretch'),
              timeOfDay: Value('evening'),
            ),
          );
      await db.into(db.routineItems).insert(
            const RoutineItemsCompanion(
              id: Value('item_a'),
              routineId: Value('routine_a'),
              title: Value('Stretch for 10 min'),
            ),
          );

      // Populate 6 consecutive active days of completions and focus
      for (int i = 0; i < 6; i++) {
        final day = now.subtract(Duration(days: i));
        final dayDate = DateTime(day.year, day.month, day.day);
        await db.into(db.studySessions).insert(
              StudySessionsCompanion(
                id: Value('study_bulk_$i'),
                subject: const Value('Algorithms'),
                durationSeconds: const Value(3600),
                actualSeconds: const Value(3600),
                sessionType: const Value('work'),
                startedAt: Value(day),
                completedAt: Value(day.add(const Duration(hours: 1))),
              ),
            );
        await db.into(db.routineCompletions).insert(
              RoutineCompletionsCompanion(
                id: Value(i + 10),
                routineId: const Value('routine_a'),
                itemId: const Value('item_a'),
                completedDate: Value(dayDate.toIso8601String().split('T').first),
                completedAt: Value(day),
              ),
            );
      }

      final report = await service.generateReportCard(range: ReportCardTimeRange.week);
      expect(report.consistencyGrade, anyOf('A+', 'A'));
      expect(report.activeDaysCount, greaterThanOrEqualTo(5));
    });

    test('Generates properly formatted CSV exports for Expenses, Study, and Telemetry', () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final end = now;

      await db.into(db.expenses).insert(
            ExpensesCompanion(
              id: const Value('exp_csv'),
              userId: const Value('local_user'),
              amount: const Value(15.75),
              category: const Value('Coffee'),
              occurredAt: Value(now),
              currency: const Value('USD'),
              note: const Value('Cold brew, oat milk'),
              tags: const Value(['coffee', 'break']),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await db.into(db.studySessions).insert(
            StudySessionsCompanion(
              id: const Value('study_csv'),
              subject: const Value('Flutter Architecture'),
              durationSeconds: const Value(2700),
              actualSeconds: const Value(2700),
              sessionType: const Value('work'),
              startedAt: Value(now),
              completedAt: Value(now.add(const Duration(minutes: 45))),
              tag: const Value('mobile-dev'),
            ),
          );

      final expensesCsv = await service.generateExpensesCsv(start: start, end: end);
      expect(expensesCsv, contains('id,occurred_at,category,amount,currency,note,tags'));
      expect(expensesCsv, contains('exp_csv'));
      expect(expensesCsv, contains('Coffee,15.75,USD'));
      expect(expensesCsv, contains('"Cold brew, oat milk"'));

      final studyCsv = await service.generateStudyCsv(start: start, end: end);
      expect(studyCsv, contains('id,started_at,completed_at,subject,session_type,target_minutes,actual_minutes,tag'));
      expect(studyCsv, contains('study_csv'));
      expect(studyCsv, contains('Flutter Architecture,work,45,45'));

      final telemetryCsv = await service.generateTelemetryCsv(start: start, end: end);
      expect(telemetryCsv, contains('date,focus_minutes,movement_meters,water_glasses,expenses_amount,routines_completed'));
      expect(telemetryCsv, contains('45')); // Focus minutes logged
      expect(telemetryCsv, contains('15.75')); // Expense logged
    });

    test('Formats clean plain-text shareable summary without emojis', () async {
      final report = ReportCardData(
        title: 'Weekly Review',
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        totalFocusMinutes: 180,
        completedFocusSessions: 4,
        totalMovementKm: 12.5,
        completedRoutinesCount: 14,
        totalExpenses: 125.0,
        totalWaterGlasses: 42.0,
        activeDaysCount: 6,
        totalDaysCount: 7,
        currentStreak: 5,
        longestStreak: 9,
        consistencyGrade: 'A',
        consistencyPercentage: 85.7,
        highlights: const [
          'High focus: 180 mins total',
          'Steady hydration rhythm',
        ],
      );

      final text = service.formatShareableTextReport(report);

      expect(text, contains('CADENCE LIFE REPORT CARD'));
      expect(text, contains('Consistency Grade: A (85.7%)'));
      expect(text, contains('Deep Focus: 3.0h (4 sessions)'));
      expect(text, contains('Movement: 12.5 km'));
      expect(text, contains('Routines: 14 completed'));
      expect(text, contains('Hydration: 42 glasses'));
      expect(text, contains('Expenses: \$125.00'));
      expect(text, isNot(contains('🎯')));
      expect(text, isNot(contains('🔥')));
    });
  });

  group('VisualReportCardScreen Widget Tests', () {
    testWidgets('Renders all report card components and switches time ranges', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: VisualReportCardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Segmented picker
      expect(find.text('Visual Report Card & Export'), findsOneWidget);
      expect(find.text('Weekly Review (7d)'), findsOneWidget);
      expect(find.text('Monthly Review (30d)'), findsOneWidget);

      // Verify Grade badge and section titles
      expect(find.text('Needs Momentum'), findsOneWidget);
      expect(find.text('DEEP WORK'), findsOneWidget);
      expect(find.text('MOVEMENT'), findsOneWidget);
      expect(find.text('ROUTINES'), findsOneWidget);
      expect(find.text('EXPENSES'), findsOneWidget);

      // Verify Export actions
      expect(find.text('SHARE & EXPORT'), findsOneWidget);
      expect(find.text('Share Report Summary'), findsOneWidget);
      expect(find.text('Export Expenses (CSV)'), findsOneWidget);
      expect(find.text('Export Focus Sessions (CSV)'), findsOneWidget);
      expect(find.text('Export Unified Daily Telemetry (CSV)'), findsOneWidget);

      // Tap Monthly Review segment
      await tester.tap(find.text('Monthly Review (30d)'));
      await tester.pumpAndSettle();

      // Screen remains responsive and stable
      expect(find.text('SHARE & EXPORT'), findsOneWidget);
    });
  });
}
