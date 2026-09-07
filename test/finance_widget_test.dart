import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/finance/presentation/finance_view.dart';
import 'package:cadence/features/finance/providers/finance_provider.dart';
import 'package:cadence/features/finance/widgets/budget_progress_card.dart';
import 'package:cadence/features/finance/widgets/category_donut_chart.dart';
import 'package:cadence/features/finance/widgets/expense_list_tile.dart';
import 'package:cadence/features/finance/widgets/month_selector_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    DateTime? initialMonth,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'finance-test-user'),
        if (initialMonth != null)
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(initialMonth)),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Finance UI Widgets', () {
    late AppDatabase db;
    final fixedMonth = DateTime(2026, 9, 1);

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('MonthSelectorBar navigates previous and next months', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const MonthSelectorBar(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show September 2026
      expect(find.text('September 2026'), findsOneWidget);

      // Tap previous month (<)
      await tester.tap(find.byTooltip('Previous Month'));
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);

      // Tap next month twice (>)
      await tester.tap(find.byTooltip('Next Month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Next Month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('CategoryDonutChart displays empty state when month has no expenses', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const CategoryDonutChart(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending by Category'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('No expenses this month'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('CategoryDonutChart renders slices and legend when expenses exist', (tester) async {
      // Seed expenses
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-test-user'),
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(fixedMonth)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(financeControllerProvider);
      await controller.logExpense(
        amount: 80.00,
        category: 'Food',
        occurredAt: DateTime(2026, 9, 5),
      );
      await controller.logExpense(
        amount: 40.00,
        category: 'Transport',
        occurredAt: DateTime(2026, 9, 10),
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const CategoryDonutChart(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('Food: '), findsOneWidget);
      expect(find.text('Transport: '), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('BudgetProgressSection displays empty card and renders progress cards when set', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const BudgetProgressSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Monthly Budgets Set'), findsOneWidget);
      expect(find.text('Set Budget'), findsOneWidget);

      // Seed a budget limit
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-test-user'),
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(fixedMonth)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(financeControllerProvider);
      await controller.setBudget(
        category: 'All',
        monthlyLimit: 500.00,
        startDate: fixedMonth,
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const BudgetProgressSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overall Monthly'), findsOneWidget);
      expect(find.text('of \$500'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ExpenseListTile renders transaction details and swipes to delete', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'finance-test-user'),
          selectedMonthProvider.overrideWith(() => SelectedMonthNotifier(fixedMonth)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(financeControllerProvider);
      final id = await controller.logExpense(
        amount: 25.50,
        category: 'Food',
        note: 'Lunch with colleagues',
        tags: ['Work', 'Social'],
        occurredAt: DateTime(2026, 9, 6, 12, 30),
      );

      final expense = await db.getExpenseById(id);
      expect(expense, isNotNull);

      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: ExpenseListTile(expense: expense!),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lunch with colleagues'), findsOneWidget);
      expect(find.text('-\$25.50'), findsOneWidget);
      expect(find.text('#Work'), findsOneWidget);
      expect(find.text('#Social'), findsOneWidget);

      // Dismiss swipe
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify soft deleted in db
      final updated = await db.getExpenseById(id);
      expect(updated?.isDeleted, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('FinanceView renders full dashboard and opens AddExpenseSheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          db: db,
          initialMonth: fixedMonth,
          child: const FinanceView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Spending by Category'), findsOneWidget);
      expect(find.text('Monthly Transactions'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);

      // Tap Add Expense FAB
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Log New Expense'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
