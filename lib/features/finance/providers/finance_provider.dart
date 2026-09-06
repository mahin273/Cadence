import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../models/finance_models.dart';

/// Currently selected viewing month for financial reports.
class SelectedMonthNotifier extends Notifier<DateTime> {
  final DateTime? _initialMonth;
  SelectedMonthNotifier([this._initialMonth]);

  @override
  DateTime build() {
    if (_initialMonth != null) {
      return DateTime(_initialMonth.year, _initialMonth.month, 1);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) => state = DateTime(month.year, month.month, 1);
  void previousMonth() => state = DateTime(state.year, state.month - 1, 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1, 1);
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(() => SelectedMonthNotifier());

/// Reactive stream of expenses for the selected calendar month.
final monthlyExpensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.watchExpensesForMonth(month);
});

/// Reactive stream of category spend summaries for the selected calendar month.
final categorySpendStreamProvider = StreamProvider<List<CategorySpend>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.watchCategorySpendSummaries(month);
});

/// Reactive stream of total monthly expense spending.
final totalMonthlySpendStreamProvider = StreamProvider<double>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final month = ref.watch(selectedMonthProvider);
  return db.watchTotalMonthlySpend(month);
});

/// Reactive stream of all active budgets.
final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchBudgets();
});

/// Combines budgets and category spends into BudgetProgress models.
final budgetProgressListProvider = Provider<List<BudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsStreamProvider).value ?? [];
  final categorySpends = ref.watch(categorySpendStreamProvider).value ?? [];
  final totalSpend = ref.watch(totalMonthlySpendStreamProvider).value ?? 0.0;

  final spendMap = {
    for (final s in categorySpends) s.category.toLowerCase(): s.totalAmount,
  };

  return budgets.map((budget) {
    double spent;
    if (budget.category.toLowerCase() == 'all') {
      spent = totalSpend;
    } else {
      spent = spendMap[budget.category.toLowerCase()] ?? 0.0;
    }

    final remaining = budget.monthlyLimit - spent;
    final percentage =
        budget.monthlyLimit > 0 ? (spent / budget.monthlyLimit) : 0.0;
    final isOverBudget = spent > budget.monthlyLimit;

    return BudgetProgress(
      budget: budget,
      spent: spent,
      remaining: remaining,
      percentage: percentage,
      isOverBudget: isOverBudget,
    );
  }).toList();
});

/// Controller handling expense creation, budget setup, and soft deletions.
class FinanceController {
  final AppDatabase _db;
  final Ref _ref;

  FinanceController(this._db, this._ref);

  /// Record and persist a new financial expense.
  Future<String> logExpense({
    required double amount,
    required String category,
    String currency = 'USD',
    String? note,
    String? receiptPath,
    List<String> tags = const [],
    DateTime? occurredAt,
  }) async {
    const uuid = Uuid();
    final expenseId = uuid.v4();
    final userId = _ref.read(activeUserIdProvider);
    final now = DateTime.now();

    await _db.upsertExpense(
      ExpensesCompanion.insert(
        id: expenseId,
        userId: userId,
        amount: amount,
        currency: drift.Value(currency),
        category: category,
        note: drift.Value(note),
        receiptPath: drift.Value(receiptPath),
        tags: drift.Value(tags),
        occurredAt: occurredAt ?? now,
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        isSynced: const drift.Value(false),
        isDeleted: const drift.Value(false),
      ),
    );

    return expenseId;
  }

  /// Soft delete an expense.
  Future<void> softDeleteExpense(String id) async {
    await _db.softDeleteExpense(id);
  }

  /// Configure or update a monthly budget limit.
  Future<String> setBudget({
    required String category,
    required double monthlyLimit,
    String currency = 'USD',
    DateTime? startDate,
  }) async {
    const uuid = Uuid();
    final budgetId = uuid.v4();
    final userId = _ref.read(activeUserIdProvider);
    final now = DateTime.now();

    await _db.upsertBudget(
      BudgetsCompanion.insert(
        id: budgetId,
        userId: userId,
        category: category,
        monthlyLimit: monthlyLimit,
        currency: drift.Value(currency),
        startDate: startDate ?? DateTime(now.year, now.month, 1),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        isSynced: const drift.Value(false),
        isDeleted: const drift.Value(false),
      ),
    );

    return budgetId;
  }

  /// Soft delete a budget limit.
  Future<void> softDeleteBudget(String id) async {
    await _db.softDeleteBudget(id);
  }
}

/// Provider exposing FinanceController.
final financeControllerProvider = Provider<FinanceController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FinanceController(db, ref);
});
