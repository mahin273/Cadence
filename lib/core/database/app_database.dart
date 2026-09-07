import 'package:drift/drift.dart';
import 'converters/json_converters.dart';
import 'tables/entries_table.dart';
import 'tables/expenses_table.dart';
import 'tables/budgets_table.dart';
import 'tables/goals_table.dart';
import 'tables/calendar_events_table.dart';
import 'tables/routes_table.dart';
import 'tables/routines_table.dart';
import 'tables/study_sessions_table.dart';
import 'tables/weekly_reviews_table.dart';
import 'connection/native_connection.dart';
import '../../features/finance/models/finance_models.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Entries,
  Expenses,
  Budgets,
  Goals,
  GoalRecords,
  CalendarEvents,
  Routes,
  RoutePoints,
  Routines,
  RoutineItems,
  RoutineCompletions,
  StudySessions,
  WeeklyReviews,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 8;

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
        if (from < 3) {
          await m.createTable(goals);
          await m.createTable(goalRecords);
        }
        if (from < 4) {
          await m.createTable(calendarEvents);
        }
        if (from < 5) {
          await m.createTable(routes);
          await m.createTable(routePoints);
        }
        if (from < 6) {
          await m.createTable(routines);
          await m.createTable(routineItems);
          await m.createTable(routineCompletions);
        }
        if (from < 7) {
          await m.createTable(studySessions);
        }
        if (from < 8) {
          await m.createTable(weeklyReviews);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
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

  // -------------------------------------------------------------
  // Goals Operations
  // -------------------------------------------------------------

  /// Watch active goals ordered chronologically.
  Stream<List<Goal>> watchActiveGoals() {
    return (select(goals)
          ..where((tbl) => tbl.active.equals(true) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  /// Get single goal by ID.
  Future<Goal?> getGoalById(String id) {
    return (select(goals)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Upsert a goal.
  Future<int> upsertGoal(GoalsCompanion goal) {
    return into(goals).insertOnConflictUpdate(goal);
  }

  /// Soft delete a goal.
  Future<int> softDeleteGoal(String id) {
    return (update(goals)..where((tbl) => tbl.id.equals(id))).write(
      GoalsCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update active status of a goal.
  Future<int> updateGoalActive(String id, bool active) {
    return (update(goals)..where((tbl) => tbl.id.equals(id))).write(
      GoalsCompanion(
        active: Value(active),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retrieve unsynced goals.
  Future<List<Goal>> getUnsyncedGoals() {
    return (select(goals)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  /// Mark goal batch as synced.
  Future<int> markGoalBatchAsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(goals)..where((tbl) => tbl.id.isIn(ids))).write(
      const GoalsCompanion(isSynced: Value(true)),
    );
  }

  // -------------------------------------------------------------
  // Goal Records Operations (Manual Logs)
  // -------------------------------------------------------------

  /// Upsert a goal record for a specific day.
  Future<int> upsertGoalRecord(GoalRecordsCompanion record) {
    return into(goalRecords).insertOnConflictUpdate(record);
  }

  /// Retrieve goal record for a specific goal and calendar day.
  Future<GoalRecord?> getGoalRecordForDate(String goalId, DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(goalRecords)
          ..where((tbl) =>
              tbl.goalId.equals(goalId) &
              tbl.date.isBiggerOrEqualValue(startOfDay) &
              tbl.date.isSmallerThanValue(endOfDay) &
              tbl.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// Watch all records for a given goal.
  Stream<List<GoalRecord>> watchGoalRecords(String goalId) {
    return (select(goalRecords)
          ..where((tbl) => tbl.goalId.equals(goalId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch();
  }

  /// Watch all active goal records.
  Stream<List<GoalRecord>> watchAllGoalRecords() {
    return (select(goalRecords)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch();
  }

  // -------------------------------------------------------------
  // Cross-Module Goal Aggregations
  // -------------------------------------------------------------

  /// Calculate sum of entry values for a given type on a specific day.
  Future<double> getDailySumForEntryType(String userId, String type, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sumCol = entries.value.sum();
    final query = selectOnly(entries)
      ..addColumns([sumCol])
      ..where(entries.userId.equals(userId) &
          entries.type.equals(type) &
          entries.occurredAt.isBiggerOrEqualValue(startOfDay) &
          entries.occurredAt.isSmallerThanValue(endOfDay) &
          entries.isDeleted.equals(false));

    final row = await query.getSingleOrNull();
    return row?.read(sumCol) ?? 0.0;
  }

  /// Count entries of a given type on a specific day (e.g. for habits).
  Future<int> getDailyCountForEntryType(String userId, String type, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final countCol = entries.id.count();
    final query = selectOnly(entries)
      ..addColumns([countCol])
      ..where(entries.userId.equals(userId) &
          entries.type.equals(type) &
          entries.occurredAt.isBiggerOrEqualValue(startOfDay) &
          entries.occurredAt.isSmallerThanValue(endOfDay) &
          entries.isDeleted.equals(false));

    final row = await query.getSingleOrNull();
    return row?.read(countCol) ?? 0;
  }

  /// Calculate total expense spend on a specific day.
  Future<double> getDailySpend(String userId, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sumCol = expenses.amount.sum();
    final query = selectOnly(expenses)
      ..addColumns([sumCol])
      ..where(expenses.userId.equals(userId) &
          expenses.occurredAt.isBiggerOrEqualValue(startOfDay) &
          expenses.occurredAt.isSmallerThanValue(endOfDay) &
          expenses.isDeleted.equals(false));

    final row = await query.getSingleOrNull();
    return row?.read(sumCol) ?? 0.0;
  }

  // -------------------------------------------------------------
  // Calendar Events Operations
  // -------------------------------------------------------------

  /// Watch active calendar events that overlap with a specified UTC time range.
  Stream<List<CalendarEvent>> watchEventsForRange(
    String userId,
    DateTime startUtc,
    DateTime endUtc,
  ) {
    return (select(calendarEvents)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.isDeleted.equals(false) &
              ((tbl.startTime.isBiggerOrEqualValue(startUtc) &
                      tbl.startTime.isSmallerOrEqualValue(endUtc)) |
                  (tbl.endTime.isBiggerOrEqualValue(startUtc) &
                      tbl.endTime.isSmallerOrEqualValue(endUtc)) |
                  (tbl.startTime.isSmallerOrEqualValue(startUtc) &
                      tbl.endTime.isBiggerOrEqualValue(endUtc))))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.startTime)]))
        .watch();
  }

  /// Watch active calendar events for a specific local calendar day.
  Stream<List<CalendarEvent>> watchEventsForDay(String userId, DateTime day) {
    final startOfDayLocal = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endOfDayLocal = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    return watchEventsForRange(
      userId,
      startOfDayLocal.toUtc(),
      endOfDayLocal.toUtc(),
    );
  }

  /// Watch all active calendar events for a user.
  Stream<List<CalendarEvent>> watchAllEvents(String userId) {
    return (select(calendarEvents)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.startTime)]))
        .watch();
  }

  /// Insert or update a calendar event.
  Future<void> upsertCalendarEvent(CalendarEventsCompanion companion) async {
    await into(calendarEvents).insertOnConflictUpdate(companion);
  }

  /// Update an existing calendar event by ID.
  Future<void> updateCalendarEvent(String id, CalendarEventsCompanion companion) async {
    await (update(calendarEvents)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  /// Soft-delete a calendar event and stage for sync.
  Future<void> softDeleteCalendarEvent(String id) async {
    await (update(calendarEvents)..where((tbl) => tbl.id.equals(id))).write(
      CalendarEventsCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // -------------------------------------------------------------
  // Routes & GPS Breadcrumbs Operations
  // -------------------------------------------------------------

  /// Insert a new route session.
  Future<void> createRoute(RoutesCompanion companion) async {
    await into(routes).insert(companion);
  }

  /// Update an existing route session (e.g. status, distance, pace, duration).
  Future<void> updateRoute(String id, RoutesCompanion companion) async {
    await (update(routes)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  /// Fetch a single route session by UUID.
  Future<Route?> getRouteById(String id) {
    return (select(routes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single route session by UUID.
  Stream<Route?> watchRouteById(String id) {
    return (select(routes)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }

  /// Watch completed routes ordered by recency.
  Stream<List<Route>> watchCompletedRoutes({int limit = 20}) {
    return (select(routes)
          ..where((tbl) => tbl.status.equals('completed'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startTime)])
          ..limit(limit))
        .watch();
  }

  /// Batch insert GPS route breadcrumb points atomically.
  Future<void> insertRoutePointsBatch(List<RoutePointsCompanion> points) async {
    if (points.isEmpty) return;
    await batch((b) {
      b.insertAll(routePoints, points);
    });
  }

  /// Fetch all recorded points for a specific route ordered sequentially.
  Future<List<RoutePoint>> getPointsForRoute(String routeId) {
    return (select(routePoints)
          ..where((tbl) => tbl.routeId.equals(routeId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.pointIndex)]))
        .get();
  }

  /// Delete a route session (will cascade delete points).
  Future<void> deleteRoute(String id) async {
    await transaction(() async {
      await (delete(routePoints)..where((tbl) => tbl.routeId.equals(id))).go();
      await (delete(routes)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  // -------------------------------------------------------------
  // Routines & Daily Scheduling Checklist Operations
  // -------------------------------------------------------------

  /// Insert a new routine.
  Future<void> createRoutine(RoutinesCompanion routine) async {
    await into(routines).insert(routine);
  }

  /// Insert a single routine checklist item.
  Future<void> createRoutineItem(RoutineItemsCompanion item) async {
    await into(routineItems).insert(item);
  }

  /// Insert a routine along with all its initial checklist items atomically.
  Future<void> createRoutineWithItems(
    RoutinesCompanion routine,
    List<RoutineItemsCompanion> items,
  ) async {
    await transaction(() async {
      await into(routines).insert(routine);
      if (items.isNotEmpty) {
        await batch((b) {
          b.insertAll(routineItems, items);
        });
      }
    });
  }

  /// Watch active routines ordered by sortOrder.
  Stream<List<Routine>> watchActiveRoutines() {
    return (select(routines)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .watch();
  }

  /// Watch checklist items for a specific routine ordered by sortOrder.
  Stream<List<RoutineItem>> watchItemsForRoutine(String routineId) {
    return (select(routineItems)
          ..where((tbl) => tbl.routineId.equals(routineId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .watch();
  }

  /// Fetch checklist items for a specific routine ordered by sortOrder.
  Future<List<RoutineItem>> getItemsForRoutine(String routineId) {
    return (select(routineItems)
          ..where((tbl) => tbl.routineId.equals(routineId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
        .get();
  }

  /// Watch item completions for a specific date string ('YYYY-MM-DD').
  Stream<List<RoutineCompletion>> watchCompletionsForDate(String dateStr) {
    return (select(routineCompletions)
          ..where((tbl) => tbl.completedDate.equals(dateStr)))
        .watch();
  }

  /// Get item completions for a specific date string ('YYYY-MM-DD').
  Future<List<RoutineCompletion>> getCompletionsForDate(String dateStr) {
    return (select(routineCompletions)
          ..where((tbl) => tbl.completedDate.equals(dateStr)))
        .get();
  }

  /// Toggle checklist item completion for a given calendar date.
  Future<bool> toggleRoutineItemCompletion(
    String routineId,
    String itemId,
    String dateStr,
  ) async {
    return await transaction(() async {
      final existing = await (select(routineCompletions)
            ..where((tbl) =>
                tbl.itemId.equals(itemId) & tbl.completedDate.equals(dateStr)))
          .getSingleOrNull();

      if (existing != null) {
        // Uncheck
        await (delete(routineCompletions)..where((tbl) => tbl.id.equals(existing.id))).go();
        return false;
      } else {
        // Check
        await into(routineCompletions).insert(
          RoutineCompletionsCompanion.insert(
            routineId: routineId,
            itemId: itemId,
            completedDate: dateStr,
            completedAt: Value(DateTime.now()),
          ),
        );
        return true;
      }
    });
  }

  /// Reorder items within a routine atomically.
  Future<void> reorderRoutineItems(List<String> itemIdsInOrder) async {
    await transaction(() async {
      for (int i = 0; i < itemIdsInOrder.length; i++) {
        await (update(routineItems)..where((tbl) => tbl.id.equals(itemIdsInOrder[i]))).write(
          RoutineItemsCompanion(
            sortOrder: Value(i),
          ),
        );
      }
    });
  }

  /// Delete a routine session and cascade delete items and completions.
  Future<void> deleteRoutine(String id) async {
    await transaction(() async {
      await (delete(routineCompletions)..where((tbl) => tbl.routineId.equals(id))).go();
      await (delete(routineItems)..where((tbl) => tbl.routineId.equals(id))).go();
      await (delete(routines)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  /// Delete a single routine item.
  Future<void> deleteRoutineItem(String itemId) async {
    await transaction(() async {
      await (delete(routineCompletions)..where((tbl) => tbl.itemId.equals(itemId))).go();
      await (delete(routineItems)..where((tbl) => tbl.id.equals(itemId))).go();
    });
  }

  // -------------------------------------------------------------
  // Study & Pomodoro Sessions
  // -------------------------------------------------------------

  /// Insert a recorded study / focus session.
  Future<void> insertStudySession(StudySessionsCompanion session) async {
    await into(studySessions).insert(session);
  }

  /// Watch recent study sessions ordered by startedAt descending.
  Stream<List<StudySession>> watchRecentStudySessions({int limit = 30}) {
    return (select(studySessions)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)])
          ..limit(limit))
        .watch();
  }

  /// Watch today's study sessions starting after local midnight.
  Stream<List<StudySession>> watchTodayStudySessions(DateTime localMidnight) {
    return (select(studySessions)
          ..where((tbl) => tbl.startedAt.isBiggerOrEqualValue(localMidnight))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)]))
        .watch();
  }

  /// Get today's total focus/work study seconds.
  Future<int> getTodayTotalStudySeconds(DateTime localMidnight) async {
    final query = selectOnly(studySessions)
      ..addColumns([studySessions.actualSeconds.sum()])
      ..where(studySessions.startedAt.isBiggerOrEqualValue(localMidnight) &
              studySessions.sessionType.equals('work'));
    final result = await query.getSingle();
    return result.read(studySessions.actualSeconds.sum()) ?? 0;
  }

  /// Delete a study session by ID.
  Future<void> deleteStudySession(String id) async {
    await (delete(studySessions)..where((tbl) => tbl.id.equals(id))).go();
  }

  // -------------------------------------------------------------
  // Weekly Reviews & Aggregation Snapshots
  // -------------------------------------------------------------

  /// Upsert a weekly review snapshot.
  Future<int> upsertWeeklyReview(WeeklyReviewsCompanion review) {
    return into(weeklyReviews).insertOnConflictUpdate(review);
  }

  /// Watch weekly review for a specific week start date.
  Stream<WeeklyReview?> watchWeeklyReviewForDate(DateTime weekStart) {
    return (select(weeklyReviews)
          ..where((tbl) => tbl.weekStartDate.equals(weekStart)))
        .watchSingleOrNull();
  }

  /// Get weekly review for a specific week start date.
  Future<WeeklyReview?> getWeeklyReviewForDate(DateTime weekStart) {
    return (select(weeklyReviews)
          ..where((tbl) => tbl.weekStartDate.equals(weekStart)))
        .getSingleOrNull();
  }

  /// Watch all weekly reviews sorted newest to oldest.
  Stream<List<WeeklyReview>> watchAllWeeklyReviews() {
    return (select(weeklyReviews)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.weekStartDate)]))
        .watch();
  }

  /// Delete a weekly review by ID.
  Future<void> deleteWeeklyReview(String id) async {
    await (delete(weeklyReviews)..where((tbl) => tbl.id.equals(id))).go();
  }
}

