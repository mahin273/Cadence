import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/features/routines/heatmaps/services/habit_streak_service.dart';
import 'package:cadence/features/routines/heatmaps/presentation/widgets/streak_summary_card.dart';
import 'package:cadence/features/routines/heatmaps/presentation/widgets/github_style_heatmap.dart';
import 'package:cadence/features/dashboard/widgets/today_vitals_bar.dart';
import 'package:cadence/features/dashboard/providers/vitals_provider.dart';

void main() {
  late AppDatabase db;
  late HabitStreakService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = HabitStreakService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HabitStreakService Unit Tests', () {
    test('Empty database yields zero streaks and empty consistency distribution', () async {
      final stats = await service.calculateConsistencyStats(days: 365);

      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
      expect(stats.totalActiveDays, 0);
      expect(stats.consistencyRate30Days, 0.0);
      expect(stats.consistencyRateYear, 0.0);
      expect(stats.dailyMap.length, 365);

      final now = DateTime.now();
      final todayKey = DateTime(now.year, now.month, now.day);
      expect(stats.getDataFor(todayKey).count, 0);
      expect(stats.getDataFor(todayKey).intensityLevel, 0);
    });

    test('Computes current streak with today grace period and updates when today logs activity', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      // Routine setup
      await db.into(db.routines).insert(
            const RoutinesCompanion(
              id: Value('rt_1'),
              title: Value('Morning Flow'),
              timeOfDay: Value('morning'),
            ),
          );
      await db.into(db.routineItems).insert(
            const RoutineItemsCompanion(
              id: Value('item_1'),
              routineId: Value('rt_1'),
              title: Value('Hydrate'),
            ),
          );

      // Log completion for 2 days ago and yesterday
      await db.into(db.routineCompletions).insert(
            RoutineCompletionsCompanion.insert(
              routineId: 'rt_1',
              itemId: 'item_1',
              completedDate: '${twoDaysAgo.year}-${twoDaysAgo.month}-${twoDaysAgo.day}',
              completedAt: Value(twoDaysAgo.add(const Duration(hours: 8))),
            ),
          );
      await db.into(db.routineCompletions).insert(
            RoutineCompletionsCompanion.insert(
              routineId: 'rt_1',
              itemId: 'item_1',
              completedDate: '${yesterday.year}-${yesterday.month}-${yesterday.day}',
              completedAt: Value(yesterday.add(const Duration(hours: 8))),
            ),
          );

      // Check stats: today has 0 activity, but yesterday is active -> grace period gives currentStreak = 2
      var stats = await service.calculateConsistencyStats(days: 30);
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
      expect(stats.totalActiveDays, 2);

      // Now user logs activity today
      await db.into(db.routineCompletions).insert(
            RoutineCompletionsCompanion.insert(
              routineId: 'rt_1',
              itemId: 'item_1',
              completedDate: '${today.year}-${today.month}-${today.day}',
              completedAt: Value(today.add(const Duration(hours: 9))),
            ),
          );

      stats = await service.calculateConsistencyStats(days: 30);
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
      expect(stats.totalActiveDays, 3);
    });

    test('Accurately tracks past longest streak even when current streak breaks', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Create a 5-day streak in the past (days 10 to 6 ago)
      for (int i = 10; i >= 6; i--) {
        final d = today.subtract(Duration(days: i));
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: 'e_past_$i',
                userId: 'u1',
                type: 'habit',
                value: 1.0,
                occurredAt: d.add(const Duration(hours: 12)),
              ),
            );
      }

      // Yesterday and today have activity (streak = 2)
      final yesterday = today.subtract(const Duration(days: 1));
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'e_yest',
              userId: 'u1',
              type: 'habit',
              value: 1.0,
              occurredAt: yesterday.add(const Duration(hours: 12)),
            ),
          );
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'e_today',
              userId: 'u1',
              type: 'habit',
              value: 1.0,
              occurredAt: today.add(const Duration(hours: 10)),
            ),
          );

      final stats = await service.calculateConsistencyStats(days: 30);
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 5);
      expect(stats.totalActiveDays, 7);
    });

    test('Scales activity intensity correctly into 5 levels (0 to 4)', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Insert 10 activities today (Level 4: Peak)
      for (int i = 0; i < 10; i++) {
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: 'e_bulk_$i',
                userId: 'u1',
                type: 'water',
                value: 1.0,
                occurredAt: today.add(Duration(minutes: i * 30)),
              ),
            );
      }

      final stats = await service.calculateConsistencyStats(days: 7);
      final todayData = stats.getDataFor(today);
      expect(todayData.count, 10);
      expect(todayData.intensityLevel, 4);
      expect(todayData.habitCount, 10);
    });
  });

  group('Streak & Heatmap Widget Tests', () {
    testWidgets('StreakSummaryCard renders current streak, record badge, and heatmap grid', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Insert 1 activity today
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w_ui',
              userId: 'u1',
              type: 'water',
              value: 1.0,
              occurredAt: today.add(const Duration(hours: 8)),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreakSummaryCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Consistency & Streaks'), findsOneWidget);
      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // Streak count of 1
      expect(find.text('30-DAY RATE'), findsOneWidget);
      expect(find.byType(GithubStyleHeatmap), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('TodayVitalsBar displays Streak vital chip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            todayVitalsSummaryProvider.overrideWithValue(
              const DailyVitalsSummary(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TodayVitalsBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('0d'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });
  });
}
