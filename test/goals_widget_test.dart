import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/goals/models/goal_models.dart';
import 'package:cadence/features/goals/widgets/goal_card.dart';
import 'package:cadence/features/goals/widgets/goals_overview_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-goals-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Goals UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('GoalsOverviewSection renders empty card and opens CreateGoalDialog', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const GoalsOverviewSection(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Daily Goals & Streaks'), findsOneWidget);
      expect(find.text('No Active Goals Set'), findsOneWidget);
      expect(find.text('Set Goal'), findsOneWidget);

      // Tap Set Goal button
      await tester.tap(find.text('Set Goal'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Goal'), findsOneWidget);
      expect(find.text('Goal Title'), findsOneWidget);
      expect(find.text('Save Goal'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('GoalCard renders goal title, streak badge, and progress ratio', (tester) async {
      final now = DateTime.now();
      final goal = Goal(
        id: 'test-goal-1',
        userId: 'test-goals-user',
        title: 'Daily Water Target',
        goalType: 'water',
        targetValue: 8.0,
        unit: 'glasses',
        period: 'daily',
        targetType: 'at_least',
        active: true,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
      );

      final progress = GoalProgress(
        goal: goal,
        currentValue: 4.0,
        targetValue: 8.0,
        isHit: false,
        percentage: 0.5,
        streakDays: 3,
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: GoalCard(progress: progress),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Water Target'), findsOneWidget);
      expect(find.text('Target: min 8 glasses'), findsOneWidget);
      expect(find.text('3d streak'), findsOneWidget);
      expect(find.text('4 / 8 glasses (50%)'), findsOneWidget);
      expect(find.text('+1 Glass'), findsOneWidget);

      // Tap +1 Glass quick action
      await tester.tap(find.text('+1 Glass'));
      await tester.pumpAndSettle();

      // Verify entry was inserted into db
      final entries = await (db.select(db.entries)).get();
      expect(entries.length, 1);
      expect(entries.first.type, 'water');
      expect(entries.first.value, 1.0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
