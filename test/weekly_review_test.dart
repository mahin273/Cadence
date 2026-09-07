import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/features/review/models/weekly_summary_data.dart';
import 'package:cadence/features/review/services/weekly_aggregation_service.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeeklyAggregationService Date Boundary Calculation', () {
    test('startOfWeek returns Monday midnight for any weekday', () {
      // Wednesday, Sep 2, 2026
      final wednesday = DateTime(2026, 9, 2, 14, 30);
      final start = WeeklyAggregationService.startOfWeek(wednesday);
      expect(start.year, 2026);
      expect(start.month, 8);
      expect(start.day, 31); // Monday, Aug 31
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);

      // Sunday, Sep 6, 2026
      final sunday = DateTime(2026, 9, 6, 23, 50);
      final sundayStart = WeeklyAggregationService.startOfWeek(sunday);
      expect(sundayStart.day, 31);

      // Monday, Aug 31, 2026
      final monday = DateTime(2026, 8, 31, 8, 0);
      final mondayStart = WeeklyAggregationService.startOfWeek(monday);
      expect(mondayStart.day, 31);
    });

    test('endOfWeek returns Sunday 23:59:59.999', () {
      final wednesday = DateTime(2026, 9, 2, 14, 30);
      final end = WeeklyAggregationService.endOfWeek(wednesday);
      expect(end.year, 2026);
      expect(end.month, 9);
      expect(end.day, 6); // Sunday, Sep 6
      expect(end.hour, 23);
      expect(end.minute, 59);
      expect(end.second, 59);
    });
  });

  group('WeeklySummaryData Model & Export', () {
    final sample = WeeklySummaryData(
      weekStartDate: DateTime(2026, 8, 31),
      weekEndDate: DateTime(2026, 9, 6, 23, 59, 59),
      compositeScore: 84,
      focusScore: 80,
      movementScore: 90,
      budgetScore: 85,
      routineScore: 81,
      totalFocusSeconds: 43200, // 12 hours
      focusSessionsCount: 16,
      topSubject: 'Thesis',
      totalSteps: 63000,
      totalDistanceKm: 18.5,
      totalExpenses: 215.50,
      weeklyBudget: 250.00,
      routineCompletedCount: 42,
      routinePossibleCount: 49,
    );

    test('JSON serialization round-trip retains exact fields', () {
      final jsonStr = sample.toJsonString();
      final parsed = WeeklySummaryData.fromJsonString(jsonStr);

      expect(parsed.compositeScore, 84);
      expect(parsed.focusScore, 80);
      expect(parsed.movementScore, 90);
      expect(parsed.budgetScore, 85);
      expect(parsed.routineScore, 81);
      expect(parsed.formattedFocusTime, '12h 0m');
      expect(parsed.topSubject, 'Thesis');
      expect(parsed.totalSteps, 63000);
      expect(parsed.totalDistanceKm, 18.5);
      expect(parsed.routinePercentage, 86);
      expect(parsed.dateRangeLabel, 'Aug 31 – Sep 6, 2026');
    });

    test('toMarkdownReport produces formatted retrospective with notes', () {
      final md = sample.toMarkdownReport(
        reflectionNotes: 'Consistent focus sessions this week; hit my running goal.',
      );

      expect(md.contains('# 📅 Weekly Review: Aug 31 – Sep 6, 2026'), isTrue);
      expect(md.contains('**Life Rhythm Score:** 84 / 100'), isTrue);
      expect(md.contains('Thesis'), isTrue);
      expect(md.contains('63000 steps'), isTrue);
      expect(md.contains('Consistent focus sessions'), isTrue);
    });
  });

  group('WeeklyAggregationService Database Execution', () {
    late AppDatabase db;
    late WeeklyAggregationService service;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      service = WeeklyAggregationService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('aggregates zero activity safely without exceptions', () async {
      final now = DateTime(2026, 9, 2);
      final summary = await service.aggregateWeek(now);

      expect(summary.compositeScore, isNotNull);
      expect(summary.focusScore, 0);
      expect(summary.movementScore, 0);
      expect(summary.totalFocusSeconds, 0);
      expect(summary.totalSteps, 0);
      expect(summary.totalExpenses, 0.0);
      // Under budget (0 <= 250) -> 100
      expect(summary.budgetScore, 100);
      // No routines configured -> 100
      expect(summary.routineScore, 100);
    });

    test('aggregates multi-domain data and calculates composite score', () async {
      final monday = DateTime(2026, 8, 31, 10, 0);

      // 1. Insert Focus Session (15 hours = 54,000s -> 100%)
      await db.insertStudySession(
        StudySessionsCompanion(
          id: const Value('study-1'),
          subject: const Value('Architecture'),
          sessionType: const Value('work'),
          durationSeconds: const Value(54000),
          actualSeconds: const Value(54000),
          startedAt: Value(monday.add(const Duration(hours: 1))),
          completedAt: Value(monday.add(const Duration(hours: 16))),
          isCompleted: const Value(true),
        ),
      );

      // 2. Insert Steps Entry (70,000 steps -> 100%)
      await db.upsertEntry(
        EntriesCompanion(
          id: const Value('entry-steps'),
          userId: const Value('user-1'),
          type: const Value('steps'),
          value: const Value(70000.0),
          occurredAt: Value(monday.add(const Duration(days: 1))),
        ),
      );

      // 3. Insert Expense ($100 spent on $1000/month [$250/wk] budget -> 100%)
      await db.into(db.expenses).insert(
        ExpensesCompanion(
          id: const Value('exp-1'),
          userId: const Value('user-1'),
          amount: const Value(100.0),
          category: const Value('Food'),
          occurredAt: Value(monday.add(const Duration(days: 2))),
        ),
      );

      // 4. Routines (1 routine with 1 item, 7 completions -> 100%)
      await db.into(db.routines).insert(
        const RoutinesCompanion(
          id: Value('routine-1'),
          title: Value('Morning Flow'),
          timeOfDay: Value('morning'),
          sortOrder: Value(0),
        ),
      );
      await db.into(db.routineItems).insert(
        const RoutineItemsCompanion(
          id: Value('item-1'),
          routineId: Value('routine-1'),
          title: Value('Meditate'),
          sortOrder: Value(0),
        ),
      );
      for (int i = 0; i < 7; i++) {
        await db.into(db.routineCompletions).insert(
          RoutineCompletionsCompanion(
            routineId: const Value('routine-1'),
            itemId: const Value('item-1'),
            completedAt: Value(monday.add(Duration(days: i))),
            completedDate: Value('2026-09-0$i'),
          ),
        );
      }

      final summary = await service.aggregateWeek(monday);

      expect(summary.focusScore, 100);
      expect(summary.movementScore, 100);
      expect(summary.budgetScore, 100);
      expect(summary.routineScore, 100);
      expect(summary.compositeScore, 100);
      expect(summary.topSubject, 'Architecture');
      expect(summary.totalSteps, 70000);
      expect(summary.totalExpenses, 100.0);
    });

    test('persists review snapshot to weekly_reviews table and retrieves it', () async {
      final now = DateTime(2026, 9, 2);
      final summary = await service.aggregateWeek(now);

      final reviewId = await service.saveReviewSnapshot(
        summary: summary,
        reflectionNotes: 'Productive and balanced week!',
        userId: 'user-review-test',
      );

      expect(reviewId, isNotEmpty);

      final saved = await service.getSavedReview(now);
      expect(saved, isNotNull);
      expect(saved!.compositeScore, summary.compositeScore);
      expect(saved.reflectionNotes, 'Productive and balanced week!');

      final restoredSummary =
          WeeklySummaryData.fromJsonString(saved.summaryJson);
      expect(restoredSummary.dateRangeLabel, summary.dateRangeLabel);
    });
  });
}
