import 'package:drift/drift.dart';
import 'converters/json_converters.dart';
import 'tables/entries_table.dart';
import 'tables/expenses_table.dart';
import 'tables/budgets_table.dart';
import 'connection/native_connection.dart';
import '../../features/finance/models/finance_models.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries, Expenses, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(expenses);
          await m.createTable(budgets);
        }
      },
    );
  }

  // -------------------------------------------------------------
  // Reactive Streams (Generic Entries)
  // -------------------------------------------------------------

  /// Watch active (non-deleted) entries sorted chronologically.
  Stream<List<Entry>> watchEntries() {
    return (select(entries)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Watch active entries filtered by type (e.g. 'water', 'habit', 'mood').
  Stream<List<Entry>> watchEntriesByType(String type) {
    return (select(entries)
          ..where((tbl) => tbl.type.equals(type) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Watch entries for a specific calendar day.
  Stream<List<Entry>> watchEntriesForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerThanValue(endOfDay) &
              tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  // -------------------------------------------------------------
  // Sync Operations (Generic Entries)
  // -------------------------------------------------------------

  /// Retrieve all entries that have not yet been synced to Supabase.
  Future<List<Entry>> getUnsyncedEntries() {
    return (select(entries)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  /// Watch count of unsynced entries for UI badges and indicators.
  Stream<int> watchUnsyncedCount() {
    final count = entries.id.count();
    final query = selectOnly(entries)
      ..addColumns([count])
      ..where(entries.isSynced.equals(false));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Retrieve single entry by UUID for conflict resolution.
  Future<Entry?> getEntryById(String id) {
    return (select(entries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Mark an entry as successfully synced with remote Supabase DB.
  Future<int> markAsSynced(String id) {
    return (update(entries)..where((tbl) => tbl.id.equals(id))).write(
      const EntriesCompanion(
        isSynced: Value(true),
      ),
    );
  }

  /// Mark a batch of entries as successfully synced in a single query.
  Future<int> markBatchAsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(entries)..where((tbl) => tbl.id.isIn(ids))).write(
      const EntriesCompanion(
        isSynced: Value(true),
      ),
    );
  }

  // -------------------------------------------------------------
  // Mutation Operations (Generic Entries)
  // -------------------------------------------------------------

  /// Insert or update an entry.
  Future<int> upsertEntry(EntriesCompanion entry) {
    return into(entries).insertOnConflictUpdate(entry);
  }

  /// Soft delete an entry so deletion can be synced to remote server.
  Future<int> softDeleteEntry(String id) {
    return (update(entries)..where((tbl) => tbl.id.equals(id))).write(
      EntriesCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard delete an entry (used for local purges).
  Future<int> hardDeleteEntry(String id) {
    return (delete(entries)..where((tbl) => tbl.id.equals(id))).go();
  }

  // -------------------------------------------------------------
  // Expenses Operations & Aggregations
  // -------------------------------------------------------------

  /// Watch active expenses ordered chronologically.
  Stream<List<Expense>> watchExpenses() {
    return (select(expenses)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Watch active expenses for a specific calendar month.
  Stream<List<Expense>> watchExpensesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return (select(expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(start) &
              tbl.occurredAt.isSmallerThanValue(end) &
              tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Reactive SQL aggregation: calculates total spend grouped by category for a month.
  Stream<List<CategorySpend>> watchCategorySpendSummaries(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final totalAmount = expenses.amount.sum();

    final query = selectOnly(expenses)
      ..addColumns([expenses.category, totalAmount])
      ..where(expenses.occurredAt.isBiggerOrEqualValue(start) &
          expenses.occurredAt.isSmallerThanValue(end) &
          expenses.isDeleted.equals(false))
      ..groupBy([expenses.category]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return CategorySpend(
          category: row.read(expenses.category)!,
          totalAmount: row.read(totalAmount) ?? 0.0,
        );
      }).toList();
    });
  }

  /// Watch total monthly expense sum across all categories.
  Stream<double> watchTotalMonthlySpend(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final total = expenses.amount.sum();

    final query = selectOnly(expenses)
      ..addColumns([total])
      ..where(expenses.occurredAt.isBiggerOrEqualValue(start) &
          expenses.occurredAt.isSmallerThanValue(end) &
          expenses.isDeleted.equals(false));

    return query.map((row) => row.read(total) ?? 0.0).watchSingle();
  }

  /// Get single expense by ID.
  Future<Expense?> getExpenseById(String id) {
    return (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Upsert an expense record.
  Future<int> upsertExpense(ExpensesCompanion expense) {
    return into(expenses).insertOnConflictUpdate(expense);
  }

  /// Soft delete an expense.
  Future<int> softDeleteExpense(String id) {
    return (update(expenses)..where((tbl) => tbl.id.equals(id))).write(
      ExpensesCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retrieve unsynced expenses.
  Future<List<Expense>> getUnsyncedExpenses() {
    return (select(expenses)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  /// Mark expense batch as synced.
  Future<int> markExpenseBatchAsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(expenses)..where((tbl) => tbl.id.isIn(ids))).write(
      const ExpensesCompanion(isSynced: Value(true)),
    );
  }

  // -------------------------------------------------------------
  // Budgets Operations
  // -------------------------------------------------------------

  /// Watch active budget limits.
  Stream<List<Budget>> watchBudgets() {
    return (select(budgets)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.category)]))
        .watch();
  }

  /// Get single budget by ID.
  Future<Budget?> getBudgetById(String id) {
    return (select(budgets)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Upsert a budget limit.
  Future<int> upsertBudget(BudgetsCompanion budget) {
    return into(budgets).insertOnConflictUpdate(budget);
  }

  /// Soft delete a budget.
  Future<int> softDeleteBudget(String id) {
    return (update(budgets)..where((tbl) => tbl.id.equals(id))).write(
      BudgetsCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retrieve unsynced budgets.
  Future<List<Budget>> getUnsyncedBudgets() {
    return (select(budgets)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  /// Mark budget batch as synced.
  Future<int> markBudgetBatchAsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(budgets)..where((tbl) => tbl.id.isIn(ids))).write(
      const BudgetsCompanion(isSynced: Value(true)),
    );
  }
}
