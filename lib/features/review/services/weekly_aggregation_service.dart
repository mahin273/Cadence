import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../models/weekly_summary_data.dart';

/// Aggregates multi-domain metrics across SQLite tables and computes
/// the composite Cadence Life Rhythm Score.
class WeeklyAggregationService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  WeeklyAggregationService(this._db);

  /// Calculates Monday 00:00:00.000 for any given date.
  static DateTime startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Calculates Sunday 23:59:59.999 for any given date.
  static DateTime endOfWeek(DateTime date) {
    final start = startOfWeek(date);
    return DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999);
  }

  /// Aggregates 7-day data across Focus, Movement, Finance, and Routines.
  Future<WeeklySummaryData> aggregateWeek(DateTime dateInWeek) async {
    final weekStart = startOfWeek(dateInWeek);
    final weekEnd = endOfWeek(dateInWeek);

    // 1. Focus Domain (Study Sessions)
    final studySessions = await (_db.select(_db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(weekStart) &
              tbl.startedAt.isSmallerOrEqualValue(weekEnd) &
              tbl.sessionType.equals('work')))
        .get();

    final focusSeconds = studySessions.fold<int>(
      0,
      (sum, s) => sum + s.actualSeconds,
    );
    final focusSessionsCount = studySessions.length;

    final subjectDurations = <String, int>{};
    for (final s in studySessions) {
      subjectDurations[s.subject] =
          (subjectDurations[s.subject] ?? 0) + s.actualSeconds;
    }
    final topSubject = subjectDurations.isEmpty
        ? 'None'
        : (subjectDurations.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    // Baseline target: 15 hours of deep focus per week (54,000 seconds)
    final focusScore =
        ((focusSeconds / 54000.0) * 100).round().clamp(0, 100);

    // 2. Movement Domain (Pedometer Entries & GPS Routes)
    final stepEntries = await (_db.select(_db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(weekStart) &
              tbl.occurredAt.isSmallerOrEqualValue(weekEnd) &
              tbl.type.equals('steps') &
              tbl.isDeleted.equals(false)))
        .get();

    final totalSteps = stepEntries.fold<int>(
      0,
      (sum, e) => sum + e.value.toInt(),
    );

    final recordedRoutes = await (_db.select(_db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(weekStart) &
              tbl.startTime.isSmallerOrEqualValue(weekEnd)))
        .get();

    final totalMeters = recordedRoutes.fold<double>(
      0.0,
      (sum, r) => sum + r.totalDistanceMeters,
    );
    final totalDistanceKm = totalMeters / 1000.0;

    // Baseline target: 70,000 steps per week (10k / day)
    final movementScore =
        ((totalSteps / 70000.0) * 100).round().clamp(0, 100);

    // 3. Finance Domain (Expenses & Monthly Budget)
    final expenseRecords = await (_db.select(_db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(weekStart) &
              tbl.occurredAt.isSmallerOrEqualValue(weekEnd) &
              tbl.isDeleted.equals(false)))
        .get();

    final totalExpenses = expenseRecords.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );

    final allBudgets = await (_db.select(_db.budgets)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .get();

    final monthlyBudget = allBudgets.isEmpty
        ? 1000.0
        : allBudgets.fold<double>(0.0, (sum, b) => sum + b.monthlyLimit);
    final weeklyBudget = monthlyBudget / 4.0;

    int budgetScore;
    if (totalExpenses <= weeklyBudget) {
      budgetScore = 100;
    } else {
      final overageRatio = (totalExpenses - weeklyBudget) / weeklyBudget;
      budgetScore = (100 - (overageRatio * 100)).round().clamp(0, 100);
    }

    // 4. Routines Domain (Completions vs Expected)
    final routineCompletions = await (_db.select(_db.routineCompletions)
          ..where((tbl) =>
              tbl.completedAt.isBiggerOrEqualValue(weekStart) &
              tbl.completedAt.isSmallerOrEqualValue(weekEnd)))
        .get();

    final allRoutineItems = await _db.select(_db.routineItems).get();
    final routinePossibleCount = allRoutineItems.length * 7;
    final routineCompletedCount = routineCompletions.length;

    final routineScore = routinePossibleCount == 0
        ? 100
        : ((routineCompletedCount / routinePossibleCount) * 100)
            .round()
            .clamp(0, 100);

    // 5. Balanced Composite Life Rhythm Score (0-100)
    final compositeScore = ((focusScore * 0.25) +
            (movementScore * 0.25) +
            (budgetScore * 0.25) +
            (routineScore * 0.25))
        .round()
        .clamp(0, 100);

    return WeeklySummaryData(
      weekStartDate: weekStart,
      weekEndDate: weekEnd,
      compositeScore: compositeScore,
      focusScore: focusScore,
      movementScore: movementScore,
      budgetScore: budgetScore,
      routineScore: routineScore,
      totalFocusSeconds: focusSeconds,
      focusSessionsCount: focusSessionsCount,
      topSubject: topSubject,
      totalSteps: totalSteps,
      totalDistanceKm: totalDistanceKm,
      totalExpenses: totalExpenses,
      weeklyBudget: weeklyBudget,
      routineCompletedCount: routineCompletedCount,
      routinePossibleCount: routinePossibleCount,
    );
  }

  /// Persist review snapshot and reflection notes into SQLite.
  Future<String> saveReviewSnapshot({
    required WeeklySummaryData summary,
    String? reflectionNotes,
    String? userId,
  }) async {
    final existing = await _db.getWeeklyReviewForDate(summary.weekStartDate);
    final id = existing?.id ?? _uuid.v4();

    final companion = WeeklyReviewsCompanion(
      id: Value(id),
      userId: Value(userId),
      weekStartDate: Value(summary.weekStartDate),
      weekEndDate: Value(summary.weekEndDate),
      compositeScore: Value(summary.compositeScore),
      summaryJson: Value(summary.toJsonString()),
      reflectionNotes: Value(reflectionNotes),
      createdAt: Value(DateTime.now()),
      isSynced: const Value(false),
    );

    await _db.upsertWeeklyReview(companion);
    return id;
  }

  /// Watch saved review from SQLite.
  Stream<WeeklyReview?> watchSavedReview(DateTime weekStart) {
    return _db.watchWeeklyReviewForDate(startOfWeek(weekStart));
  }

  /// Get saved review from SQLite.
  Future<WeeklyReview?> getSavedReview(DateTime weekStart) {
    return _db.getWeeklyReviewForDate(startOfWeek(weekStart));
  }
}
