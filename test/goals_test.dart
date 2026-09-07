import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/entries/providers/entries_provider.dart';
import 'package:cadence/features/finance/providers/finance_provider.dart';
import 'package:cadence/features/goals/providers/goals_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoalsController & Database Operations', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-goals-user';

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => testUserId),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('createGoal persists new goal with correct default attributes and UUID', () async {
      final controller = container.read(goalsControllerProvider);

      final goalId = await controller.createGoal(
        title: 'Drink 8 Glasses',
        goalType: 'water',
        targetValue: 8.0,
        unit: 'glasses',
        period: 'daily',
        targetType: 'at_least',
      );

      final goal = await db.getGoalById(goalId);
      expect(goal, isNotNull);
      expect(goal!.title, 'Drink 8 Glasses');
      expect(goal.goalType, 'water');
      expect(goal.targetValue, 8.0);
      expect(goal.unit, 'glasses');
      expect(goal.period, 'daily');
      expect(goal.targetType, 'at_least');
      expect(goal.active, isTrue);
      expect(goal.isSynced, isFalse);
      expect(goal.isDeleted, isFalse);
    });

    test('softDeleteGoal sets isDeleted flag and marks isSynced false', () async {
      final controller = container.read(goalsControllerProvider);

      final goalId = await controller.createGoal(
        title: 'Morning Run',
        goalType: 'steps',
        targetValue: 10000.0,
      );

      var activeGoals = await db.watchActiveGoals().first;
      expect(activeGoals.any((g) => g.id == goalId), isTrue);

      await controller.softDeleteGoal(goalId);

      activeGoals = await db.watchActiveGoals().first;
      expect(activeGoals.any((g) => g.id == goalId), isFalse);

      final row = await db.getGoalById(goalId);
      expect(row?.isDeleted, isTrue);
      expect(row?.isSynced, isFalse);
    });

    test('toggleActive updates active status', () async {
      final controller = container.read(goalsControllerProvider);

      final goalId = await controller.createGoal(
        title: 'Read Book',
        goalType: 'custom',
        targetValue: 30.0,
      );

      await controller.toggleActive(goalId, true);
      var goal = await db.getGoalById(goalId);
      expect(goal?.active, isFalse);

      await controller.toggleActive(goalId, false);
      goal = await db.getGoalById(goalId);
      expect(goal?.active, isTrue);
    });

    test('logManualProgress creates and updates goal record for date', () async {
      final controller = container.read(goalsControllerProvider);
      final today = DateTime(2026, 9, 8);

      final goalId = await controller.createGoal(
        title: 'Meditation',
        goalType: 'custom',
        targetValue: 15.0,
      );

      await controller.logManualProgress(
        goalId: goalId,
        achievedValue: 10.0,
        isHit: false,
        date: today,
      );

      var record = await db.getGoalRecordForDate(goalId, today);
      expect(record, isNotNull);
      expect(record!.achievedValue, 10.0);
      expect(record.isHit, isFalse);

      // Update same date
      await controller.logManualProgress(
        goalId: goalId,
        achievedValue: 20.0,
        isHit: true,
        date: today,
      );

      record = await db.getGoalRecordForDate(goalId, today);
      expect(record?.achievedValue, 20.0);
      expect(record?.isHit, isTrue);
    });
  });

  group('Cross-Module Goal Evaluation & Streaks', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-goals-user';

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => testUserId),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('Water goal dynamically evaluates against entries table', () async {
      final goalsController = container.read(goalsControllerProvider);
      final entryController = container.read(entryControllerProvider);
      final today = DateTime.now();

      final goalId = await goalsController.createGoal(
        title: 'Hydration',
        goalType: 'water',
        targetValue: 8.0,
        unit: 'glasses',
        targetType: 'at_least',
      );

      final goal = (await db.getGoalById(goalId))!;
      final evaluator = GoalEvaluationService(db: db, userId: testUserId);

      // Initially 0 glasses
      var eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 0.0);
      expect(eval.isHit, isFalse);

      // Log 3 glasses
      await entryController.logEntry(
        type: 'water',
        value: 3.0,
        occurredAt: today,
      );

      eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 3.0);
      expect(eval.isHit, isFalse);

      // Log 5 more glasses (total 8)
      await entryController.logEntry(
        type: 'water',
        value: 5.0,
        occurredAt: today,
      );

      eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 8.0);
      expect(eval.isHit, isTrue);
    });

    test('Spend goal dynamically evaluates against expenses table with at_most logic', () async {
      final goalsController = container.read(goalsControllerProvider);
      final financeController = container.read(financeControllerProvider);
      final today = DateTime.now();

      final goalId = await goalsController.createGoal(
        title: 'Daily Spend Limit',
        goalType: 'spend',
        targetValue: 50.0,
        unit: '\$',
        targetType: 'at_most',
      );

      final goal = (await db.getGoalById(goalId))!;
      final evaluator = GoalEvaluationService(db: db, userId: testUserId);

      // Initially 0 spend -> <= 50 so isHit is true
      var eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 0.0);
      expect(eval.isHit, isTrue);

      // Spend $30 -> still <= 50
      await financeController.logExpense(
        amount: 30.0,
        category: 'Food',
        occurredAt: today,
      );

      eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 30.0);
      expect(eval.isHit, isTrue);

      // Spend $35 more (total $65) -> exceeds $50 limit -> isHit is false
      await financeController.logExpense(
        amount: 35.0,
        category: 'Entertainment',
        occurredAt: today,
      );

      eval = await evaluator.evaluateGoalForDay(goal, today);
      expect(eval.currentValue, 65.0);
      expect(eval.isHit, isFalse);
    });

    test('calculateStreak correctly computes consecutive days with grace period for today', () async {
      final goalsController = container.read(goalsControllerProvider);
      final entryController = container.read(entryControllerProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      final goalId = await goalsController.createGoal(
        title: 'Daily Water Streak',
        goalType: 'water',
        targetValue: 8.0,
      );

      final goal = (await db.getGoalById(goalId))!;
      final evaluator = GoalEvaluationService(db: db, userId: testUserId);

      // Seed historical data:
      // 3 days ago: 4 glasses (missed, broke prior streak)
      await entryController.logEntry(type: 'water', value: 4.0, occurredAt: threeDaysAgo);
      // 2 days ago: 8 glasses (hit)
      await entryController.logEntry(type: 'water', value: 8.0, occurredAt: twoDaysAgo);
      // Yesterday: 8 glasses (hit)
      await entryController.logEntry(type: 'water', value: 8.0, occurredAt: yesterday);

      // Case 1: Today not yet completed (0 glasses) -> grace period preserves streak = 2
      var streak = await evaluator.calculateStreak(goal, today);
      expect(streak, 2);

      // Case 2: Complete today with 8 glasses -> streak becomes 3
      await entryController.logEntry(type: 'water', value: 8.0, occurredAt: today);
      streak = await evaluator.calculateStreak(goal, today);
      expect(streak, 3);
    });

    test('dailyGoalsProgressProvider emits calculated progress items reactively', () async {
      final goalsController = container.read(goalsControllerProvider);
      final entryController = container.read(entryControllerProvider);

      // Keep subscriptions active
      final sub = container.listen(dailyGoalsProgressProvider, (_, _) {});
      addTearDown(sub.close);

      await goalsController.createGoal(
        title: 'Water Target',
        goalType: 'water',
        targetValue: 10.0,
        unit: 'glasses',
      );

      // Log 5 glasses
      await entryController.logEntry(
        type: 'water',
        value: 5.0,
        occurredAt: DateTime.now(),
      );

      // Await database streams to guarantee data is written
      final goals = await db.watchActiveGoals().first;
      expect(goals.length, 1);

      // Flush Riverpod provider listeners
      await pumpEventQueue();

      final progressList = container.read(dailyGoalsProgressProvider);
      expect(progressList.length, 1);

      final item = progressList.first;
      expect(item.goal.title, 'Water Target');
      expect(item.currentValue, 5.0);
      expect(item.targetValue, 10.0);
      expect(item.percentage, 0.5);
      expect(item.isHit, isFalse);
    });
  });
}
