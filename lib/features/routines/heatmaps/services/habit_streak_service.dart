import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../models/habit_streak_models.dart';

/// Aggregation engine computing daily habit and routine activity frequencies,
/// streaks, personal records, and contribution heatmap distributions.
class HabitStreakService {
  final AppDatabase db;

  HabitStreakService(this.db);

  /// Computes comprehensive streak and 365-day heatmap consistency statistics.
  Future<StreakStats> calculateConsistencyStats({int days = 365}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: days - 1));
    final endDate = today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    // 1. Fetch Routine completions
    final completions = await (db.select(db.routineCompletions)
          ..where((tbl) =>
              tbl.completedAt.isBiggerOrEqualValue(startDate) &
              tbl.completedAt.isSmallerOrEqualValue(endDate)))
        .get();

    // 2. Fetch Study Sessions
    final studySessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(startDate) &
              tbl.startedAt.isSmallerOrEqualValue(endDate)))
        .get();

    // 3. Fetch Routes
    final routes = await (db.select(db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startDate) &
              tbl.startTime.isSmallerOrEqualValue(endDate)))
        .get();

    // 4. Fetch Entries (habits, water, journal)
    final entries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startDate) &
              tbl.occurredAt.isSmallerOrEqualValue(endDate) &
              tbl.isDeleted.equals(false)))
        .get();

    // Aggregation buckets per calendar date
    final Map<DateTime, int> routineCounts = {};
    final Map<DateTime, int> focusCounts = {};
    final Map<DateTime, int> movementCounts = {};
    final Map<DateTime, int> habitCounts = {};

    DateTime toDateKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    for (final c in completions) {
      final k = toDateKey(c.completedAt);
      routineCounts[k] = (routineCounts[k] ?? 0) + 1;
    }

    for (final s in studySessions) {
      final k = toDateKey(s.startedAt);
      focusCounts[k] = (focusCounts[k] ?? 0) + 1;
    }

    for (final r in routes) {
      final k = toDateKey(r.startTime);
      movementCounts[k] = (movementCounts[k] ?? 0) + 1;
    }

    for (final e in entries) {
      final k = toDateKey(e.occurredAt);
      habitCounts[k] = (habitCounts[k] ?? 0) + 1;
    }

    // Populate full day map for the requested time window
    final Map<DateTime, DayConsistencyData> dailyMap = {};
    int totalActiveDays = 0;
    int last30ActiveDays = 0;
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));

    for (int i = 0; i < days; i++) {
      final d = startDate.add(Duration(days: i));
      final key = toDateKey(d);

      final rCount = routineCounts[key] ?? 0;
      final fCount = focusCounts[key] ?? 0;
      final mCount = movementCounts[key] ?? 0;
      final hCount = habitCounts[key] ?? 0;
      final total = rCount + fCount + mCount + hCount;

      final int intensity;
      if (total == 0) {
        intensity = 0;
      } else if (total <= 2) {
        intensity = 1;
      } else if (total <= 5) {
        intensity = 2;
      } else if (total <= 8) {
        intensity = 3;
      } else {
        intensity = 4;
      }

      if (total > 0) {
        totalActiveDays++;
        if (key.isAfter(thirtyDaysAgo) || key.isAtSameMomentAs(thirtyDaysAgo)) {
          last30ActiveDays++;
        }
      }

      dailyMap[key] = DayConsistencyData(
        date: key,
        count: total,
        intensityLevel: intensity,
        routineCount: rCount,
        focusCount: fCount,
        movementCount: mCount,
        habitCount: hCount,
      );
    }

    // Calculate Longest Streak across all days in window
    int longestStreak = 0;
    int runningStreak = 0;
    for (int i = 0; i < days; i++) {
      final d = startDate.add(Duration(days: i));
      final key = toDateKey(d);
      final count = dailyMap[key]?.count ?? 0;

      if (count > 0) {
        runningStreak++;
        if (runningStreak > longestStreak) {
          longestStreak = runningStreak;
        }
      } else {
        runningStreak = 0;
      }
    }

    // Calculate Current Streak (with grace period for today)
    int currentStreak = 0;
    final todayData = dailyMap[today];
    final yesterday = today.subtract(const Duration(days: 1));

    if (todayData != null && todayData.count > 0) {
      // Today already has activity; count today + previous consecutive days
      currentStreak = 1;
      DateTime checkDate = yesterday;
      while (true) {
        final data = dailyMap[checkDate];
        if (data != null && data.count > 0) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    } else {
      // Today doesn't have activity yet; check if yesterday was active (grace period)
      DateTime checkDate = yesterday;
      while (true) {
        final data = dailyMap[checkDate];
        if (data != null && data.count > 0) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    final double rate30 = (last30ActiveDays / 30.0 * 100.0).clamp(0.0, 100.0);
    final double rateYear = (totalActiveDays / days * 100.0).clamp(0.0, 100.0);

    return StreakStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalActiveDays: totalActiveDays,
      consistencyRate30Days: double.parse(rate30.toStringAsFixed(1)),
      consistencyRateYear: double.parse(rateYear.toStringAsFixed(1)),
      dailyMap: dailyMap,
    );
  }
}
