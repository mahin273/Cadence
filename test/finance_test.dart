import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/finance/providers/finance_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expenses Table & Drift Operations', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-user-1'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('logExpense inserts expense record with tags and receipt path', () async {
      final controller = container.read(financeControllerProvider);
      final now = DateTime(2026, 9, 6, 14, 30);

      final id = await controller.logExpense(
        amount: 42.50,
        category: 'Food',
        currency: 'USD',
        note: 'Supermarket groceries',
        receiptPath: '/data/user/0/cadence/receipt_001.jpg',
        tags: ['Groceries', 'Weekly'],
        occurredAt: now,
      );

      final expense = await db.getExpenseById(id);
      expect(expense, isNotNull);
      expect(expense!.amount, 42.50);
      expect(expense.category, 'Food');
      expect(expense.currency, 'USD');
      expect(expense.note, 'Supermarket groceries');
      expect(expense.receiptPath, '/data/user/0/cadence/receipt_001.jpg');
      expect(expense.tags, ['Groceries', 'Weekly']);
      expect(expense.userId, 'finance-user-1');
      expect(expense.isSynced, isFalse);
      expect(expense.isDeleted, isFalse);
    });

    test('softDeleteExpense excludes item from active stream and stages for sync', () async {
      final controller = container.read(financeControllerProvider);

      final id = await controller.logExpense(
        amount: 15.00,
        category: 'Transport',
        note: 'Bus fare',
      );

      var activeExpenses = await db.watchExpenses().first;
      expect(activeExpenses.any((e) => e.id == id), isTrue);

      await controller.softDeleteExpense(id);

      activeExpenses = await db.watchExpenses().first;
      expect(activeExpenses.any((e) => e.id == id), isFalse);

      final record = await db.getExpenseById(id);
      expect(record?.isDeleted, isTrue);
      expect(record?.isSynced, isFalse);
    });
  });

  group('SQL Aggregations: Monthly Category Spend & Totals', () {
    late AppDatabase db;
    late ProviderContainer container;
    final testMonth = DateTime(2026, 9, 1);

    setUp(() async {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-user-1'),
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(testMonth)),
        ],
      );

      final controller = container.read(financeControllerProvider);

      // Current month expenses (Sept 2026)
      await controller.logExpense(
        amount: 50.00,
        category: 'Food',
        occurredAt: DateTime(2026, 9, 5),
      );
      await controller.logExpense(
        amount: 30.00,
        category: 'Food',
        occurredAt: DateTime(2026, 9, 10),
      );
      await controller.logExpense(
        amount: 25.00,
        category: 'Transport',
        occurredAt: DateTime(2026, 9, 12),
      );
      await controller.logExpense(
        amount: 100.00,
        category: 'Utilities',
        occurredAt: DateTime(2026, 9, 15),
      );

      // Previous month expense (August 2026 - must be excluded)
      await controller.logExpense(
        amount: 200.00,
        category: 'Food',
        occurredAt: DateTime(2026, 8, 25),
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('watchExpensesForMonth filters strictly to targeted calendar month', () async {
      final septExpenses = await db.watchExpensesForMonth(testMonth).first;
      expect(septExpenses.length, 4);
      expect(septExpenses.every((e) => e.occurredAt.month == 9), isTrue);
    });

    test('watchCategorySpendSummaries aggregates total amount per category via SQL GROUP BY', () async {
      final summaries = await db.watchCategorySpendSummaries(testMonth).first;
      final summaryMap = {for (final s in summaries) s.category: s.totalAmount};

      expect(summaryMap['Food'], 80.00);
      expect(summaryMap['Transport'], 25.00);
      expect(summaryMap['Utilities'], 100.00);
      expect(summaryMap.containsKey('Housing'), isFalse);
    });

    test('watchTotalMonthlySpend calculates complete sum for target month', () async {
      final total = await db.watchTotalMonthlySpend(testMonth).first;
      // 50 + 30 + 25 + 100 = 205.00 (August $200 excluded)
      expect(total, 205.00);
    });
  });

  group('Budgets & Burn-Rate Progress Calculations', () {
    late AppDatabase db;
    late ProviderContainer container;
    final targetMonth = DateTime(2026, 9, 1);

    setUp(() async {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-user-1'),
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(targetMonth)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('budgetProgressListProvider calculates remaining balance and over-budget flag', () async {
      final controller = container.read(financeControllerProvider);

      // Keep subscription active so StreamProviders update reactively
      final sub = container.listen(budgetProgressListProvider, (_, _) {});
      addTearDown(sub.close);

      // Set Food budget of $100
      await controller.setBudget(
        category: 'Food',
        monthlyLimit: 100.00,
        startDate: targetMonth,
      );

      // Set All overall budget of $500
      await controller.setBudget(
        category: 'All',
        monthlyLimit: 500.00,
        startDate: targetMonth,
      );

      // Spend $75 on Food
      await controller.logExpense(
        amount: 75.00,
        category: 'Food',
        occurredAt: DateTime(2026, 9, 4),
      );

      // Await database stream to guarantee data is written and query has run
      final foodSpend = await db.watchCategorySpendSummaries(targetMonth).first;
      expect(foodSpend.first.totalAmount, 75.00);

      // Flush Riverpod provider listeners
      await pumpEventQueue();

      // Read budget progress
      final progressList = container.read(budgetProgressListProvider);
      expect(progressList.length, 2);

      final foodProgress = progressList.firstWhere((p) => p.budget.category == 'Food');
      expect(foodProgress.spent, 75.00);
      expect(foodProgress.remaining, 25.00);
      expect(foodProgress.percentage, 0.75);
      expect(foodProgress.isOverBudget, isFalse);

      final allProgress = progressList.firstWhere((p) => p.budget.category == 'All');
      expect(allProgress.spent, 75.00);
      expect(allProgress.remaining, 425.00);
      expect(allProgress.percentage, 0.15);
      expect(allProgress.isOverBudget, isFalse);

      // Spend another $35 on Food ($110 total) -> over-budget condition
      await controller.logExpense(
        amount: 35.00,
        category: 'Food',
        occurredAt: DateTime(2026, 9, 8),
      );

      await pumpEventQueue();
      final updatedList = container.read(budgetProgressListProvider);
      final updatedFood = updatedList.firstWhere((p) => p.budget.category == 'Food');

      expect(updatedFood.spent, 110.00);
      expect(updatedFood.remaining, -10.00);
      expect(updatedFood.percentage, 1.10);
      expect(updatedFood.isOverBudget, isTrue);
    });
  });
}
