import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../models/goal_models.dart';

/// Stream provider for all active goals in Drift database.
final activeGoalsStreamProvider = StreamProvider<List<Goal>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchActiveGoals();
});

/// Evaluator service to calculate goal progress and historical streaks.
class GoalEvaluationService {
  final AppDatabase db;
  final String userId;

  GoalEvaluationService({required this.db, required this.userId});

  /// Evaluates the achieved value and success status for a given goal on a specific calendar day.
  Future<({double currentValue, bool isHit})> evaluateGoalForDay(
    Goal goal,
    DateTime day,
  ) async {
    double current = 0.0;

    switch (goal.goalType.toLowerCase()) {
      case 'water':
        current = await db.getDailySumForEntryType(userId, 'water', day);
        break;
      case 'steps':
        current = await db.getDailySumForEntryType(userId, 'steps', day);
        break;
      case 'study':
        current = await db.getDailySumForEntryType(userId, 'study', day);
        break;
      case 'habit':
        final count = await db.getDailyCountForEntryType(userId, 'habit', day);
        current = count.toDouble();
        break;
      case 'spend':
        current = await db.getDailySpend(userId, day);
        break;
      case 'custom':
      default:
        final record = await db.getGoalRecordForDate(goal.id, day);
        current = record?.achievedValue ?? 0.0;
        break;
    }

    final bool isHit;
    if (goal.targetType == 'at_most') {
      isHit = current <= goal.targetValue;
    } else {
      isHit = current >= goal.targetValue;
    }

    return (currentValue: current, isHit: isHit);
  }

  /// Calculates the consecutive unbroken streak in days for a daily goal.
  /// Includes an ongoing grace period for today if today is not yet hit but yesterday was.
  Future<int> calculateStreak(Goal goal, DateTime today) async {
    final todayEval = await evaluateGoalForDay(goal, today);
    int streak = 0;
    DateTime checkDay;

    if (todayEval.isHit) {
      streak = 1;
      checkDay = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));
    } else {
      // Check yesterday for grace period
      final yesterday = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));
      final yesterdayEval = await evaluateGoalForDay(goal, yesterday);
      if (yesterdayEval.isHit) {
        streak = 1;
        checkDay = yesterday.subtract(const Duration(days: 1));
      } else {
        return 0; // Streak broken
      }
    }

    // Walk backwards day by day (capped to 365 days)
    for (int i = 0; i < 365; i++) {
      final pastEval = await evaluateGoalForDay(goal, checkDay);
      if (pastEval.isHit) {
        streak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}

/// Stream provider for all active goal records in Drift database.
final allGoalRecordsStreamProvider = StreamProvider<List<GoalRecord>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllGoalRecords();
});

/// Reactive provider computing real-time daily progress and streaks for all active goals.
final dailyGoalsProgressProvider = Provider<List<GoalProgress>>((ref) {
  final activeGoals = ref.watch(activeGoalsStreamProvider).value ?? [];
  final allEntries = ref.watch(entriesStreamProvider).value ?? [];
  final allExpenses = ref.watch(allExpensesStreamProvider).value ?? [];
  final allRecords = ref.watch(allGoalRecordsStreamProvider).value ?? [];

  if (activeGoals.isEmpty) return [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ({double currentValue, bool isHit}) evaluateForDay(Goal goal, DateTime day) {
    double current = 0.0;
    switch (goal.goalType.toLowerCase()) {
      case 'water':
        current = allEntries
            .where((e) => e.type == 'water' && isSameDay(e.occurredAt, day))
            .fold(0.0, (sum, e) => sum + e.value);
        break;
      case 'steps':
        current = allEntries
            .where((e) => e.type == 'steps' && isSameDay(e.occurredAt, day))
            .fold(0.0, (sum, e) => sum + e.value);
        break;
      case 'study':
        current = allEntries
            .where((e) => e.type == 'study' && isSameDay(e.occurredAt, day))
            .fold(0.0, (sum, e) => sum + e.value);
        break;
      case 'habit':
        current = allEntries
            .where((e) => e.type == 'habit' && isSameDay(e.occurredAt, day))
            .length
            .toDouble();
        break;
      case 'spend':
        current = allExpenses
            .where((e) => isSameDay(e.occurredAt, day))
            .fold(0.0, (sum, e) => sum + e.amount);
        break;
      case 'custom':
      default:
        final match = allRecords.cast<GoalRecord?>().firstWhere(
              (r) => r != null && r.goalId == goal.id && isSameDay(r.date, day),
              orElse: () => null,
            );
        current = match?.achievedValue ?? 0.0;
        break;
    }

    final bool isHit = goal.targetType == 'at_most'
        ? current <= goal.targetValue
        : current >= goal.targetValue;

    return (currentValue: current, isHit: isHit);
  }

  int calculateStreak(Goal goal) {
    final todayEval = evaluateForDay(goal, today);
    int streak = 0;
    DateTime checkDay;

    if (todayEval.isHit) {
      streak = 1;
      checkDay = today.subtract(const Duration(days: 1));
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayEval = evaluateForDay(goal, yesterday);
      if (yesterdayEval.isHit) {
        streak = 1;
        checkDay = yesterday.subtract(const Duration(days: 1));
      } else {
        return 0;
      }
    }

    for (int i = 0; i < 365; i++) {
      final pastEval = evaluateForDay(goal, checkDay);
      if (pastEval.isHit) {
        streak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  return activeGoals.map((goal) {
    final eval = evaluateForDay(goal, today);
    final streak = calculateStreak(goal);
    final percentage = goal.targetValue > 0 ? (eval.currentValue / goal.targetValue) : 0.0;

    return GoalProgress(
      goal: goal,
      currentValue: eval.currentValue,
      targetValue: goal.targetValue,
      isHit: eval.isHit,
      percentage: percentage,
      streakDays: streak,
    );
  }).toList();
});

/// Controller handling user actions on goals (create, soft-delete, manual increment).
class GoalsController {
  final Ref ref;
  final _uuid = const Uuid();

  GoalsController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String get _userId => ref.read(activeUserIdProvider) ?? 'offline-guest';

  /// Create a new goal with initial values.
  Future<String> createGoal({
    required String title,
    required String goalType,
    required double targetValue,
    String? unit,
    String period = 'daily',
    String targetType = 'at_least',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.upsertGoal(
      GoalsCompanion(
        id: Value(id),
        userId: Value(_userId),
        title: Value(title.trim()),
        goalType: Value(goalType.toLowerCase()),
        targetValue: Value(targetValue),
        unit: Value(unit?.trim()),
        period: Value(period),
        targetType: Value(targetType),
        active: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSynced: const Value(false),
        isDeleted: const Value(false),
      ),
    );

    return id;
  }

  /// Soft delete a goal.
  Future<void> softDeleteGoal(String id) async {
    await _db.softDeleteGoal(id);
  }

  /// Toggle goal active status.
  Future<void> toggleActive(String id, bool currentActive) async {
    await _db.updateGoalActive(id, !currentActive);
  }

  /// Log or increment manual progress for custom goals.
  Future<void> logManualProgress({
    required String goalId,
    required double achievedValue,
    required bool isHit,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final normalizedDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final now = DateTime.now();

    // Check if record exists for this day
    final existing = await _db.getGoalRecordForDate(goalId, normalizedDay);
    final id = existing?.id ?? _uuid.v4();

    await _db.upsertGoalRecord(
      GoalRecordsCompanion(
        id: Value(id),
        goalId: Value(goalId),
        userId: Value(_userId),
        date: Value(normalizedDay),
        achievedValue: Value(achievedValue),
        isHit: Value(isHit),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
        isSynced: const Value(false),
        isDeleted: const Value(false),
      ),
    );
  }
}

final goalsControllerProvider = Provider<GoalsController>((ref) {
  return GoalsController(ref);
});
