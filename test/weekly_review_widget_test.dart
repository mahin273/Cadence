import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/review/models/weekly_summary_data.dart';
import 'package:cadence/features/review/services/weekly_aggregation_service.dart';
import 'package:cadence/features/review/presentation/weekly_review_view.dart';
import 'package:cadence/features/review/providers/weekly_review_providers.dart';
import 'package:cadence/features/review/widgets/score_gauge.dart';
import 'package:cadence/features/review/widgets/weekly_domain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Weekly Review UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('ScoreGauge displays animated score and appropriate rhythm label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScoreGauge(score: 88),
          ),
        ),
      );

      // Fast-forward animation
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('88'), findsOneWidget);
      expect(find.text('LIFE RHYTHM'), findsOneWidget);
      expect(find.text('Flourishing'), findsOneWidget);
    });

    testWidgets('WeeklyDomainCard displays domain info, scores, and status tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeeklyDomainCard(
              title: 'Focus & Deep Work',
              icon: Icons.psychology_rounded,
              accentColor: Colors.purple,
              score: 92,
              primaryMetric: '15h 30m',
              secondaryMetric: '20 sessions • Top: AI Research',
              statusText: 'Target Met',
            ),
          ),
        ),
      );

      expect(find.text('Focus & Deep Work'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('15h 30m'), findsOneWidget);
      expect(find.text('20 sessions • Top: AI Research'), findsOneWidget);
      expect(find.text('Target Met'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });

    testWidgets('WeeklyReviewView renders full review dashboard, domain cards, and handles saving', (tester) async {
      final now = DateTime.now();
      final sampleWeekStart = WeeklyAggregationService.startOfWeek(now);
      final sampleWeekEnd = WeeklyAggregationService.endOfWeek(now);

      final testSummary = WeeklySummaryData(
        weekStartDate: sampleWeekStart,
        weekEndDate: sampleWeekEnd,
        compositeScore: 78,
        focusScore: 75,
        movementScore: 82,
        budgetScore: 80,
        routineScore: 75,
        totalFocusSeconds: 36000,
        focusSessionsCount: 14,
        topSubject: 'Algorithms',
        totalSteps: 57400,
        totalDistanceKm: 12.4,
        totalExpenses: 180.00,
        weeklyBudget: 250.00,
        routineCompletedCount: 38,
        routinePossibleCount: 49,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          weeklySummaryProvider(sampleWeekStart).overrideWith(
            (ref) => Future.value(testSummary),
          ),
          savedWeeklyReviewProvider(sampleWeekStart).overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WeeklyReviewView(),
          ),
        ),
      );

      // Pump data resolution and gauge animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Weekly Review'), findsOneWidget);
      expect(find.text('Domain Breakdown'), findsOneWidget);
      expect(find.text('Focus & Deep Work'), findsOneWidget);
      expect(find.text('Movement & Health'), findsOneWidget);
      expect(find.text('Financial Health'), findsOneWidget);
      expect(find.text('Daily Routines'), findsOneWidget);
      expect(find.text('Weekly Reflection & Journal'), findsOneWidget);
      expect(find.text('Save Review Snapshot'), findsOneWidget);
      expect(find.text('Export Markdown'), findsOneWidget);

      // Enter reflection notes
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.ensureVisible(textField);
      await tester.enterText(textField, 'Great focus on algorithms this week!');
      await tester.pump();

      // Tap save snapshot button
      final saveBtn = find.text('Save Review Snapshot');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Weekly review snapshot saved to local database!'), findsOneWidget);

      // Verify that the review was indeed persisted into SQLite
      final savedInDb = await db.getWeeklyReviewForDate(sampleWeekStart);
      expect(savedInDb, isNotNull);
      expect(savedInDb!.compositeScore, 78);
      expect(savedInDb.reflectionNotes, 'Great focus on algorithms this week!');

      // Proper tear-down sequence
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
