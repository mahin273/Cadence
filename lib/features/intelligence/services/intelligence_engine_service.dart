import 'dart:math';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../models/life_intelligence_models.dart';

/// Offline analytical engine that correlates behaviors across all Cadence domains.
class IntelligenceEngineService {
  final AppDatabase db;

  IntelligenceEngineService(this.db);

  static DateTime normalizeDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Synthesize all cross-domain data points into an IntelligenceReport.
  Future<IntelligenceReport> analyzeTimeWindow({int days = 14}) async {
    final now = DateTime.now();
    final today = normalizeDate(now);
    final startDate = today.subtract(Duration(days: days - 1));
    final endDate = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    // 1. Fetch Focus Sessions
    final studySessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(startDate) &
              tbl.startedAt.isSmallerOrEqualValue(endDate) &
              tbl.sessionType.equals('work')))
        .get();

    // 2. Fetch Screen Time Snapshots
    final screenSnapshots = await (db.select(db.screenTimeSnapshots)
          ..where((tbl) =>
              tbl.date.isBiggerOrEqualValue(startDate) &
              tbl.date.isSmallerOrEqualValue(endDate)))
        .get();

    // 3. Fetch Hydration (Water Entries)
    final waterEntries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startDate) &
              tbl.occurredAt.isSmallerOrEqualValue(endDate) &
              tbl.type.equals('water') &
              tbl.isDeleted.equals(false)))
        .get();

    // 4. Fetch GPS Routes
    final routes = await (db.select(db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startDate) &
              tbl.startTime.isSmallerOrEqualValue(endDate)))
        .get();

    // 5. Fetch Routines and Routine Completions
    final routineItemsList = await db.select(db.routineItems).get();
    final totalRoutineItemsPerDay = max(1, routineItemsList.length);

    final completions = await (db.select(db.routineCompletions)
          ..where((tbl) =>
              tbl.completedAt.isBiggerOrEqualValue(startDate) &
              tbl.completedAt.isSmallerOrEqualValue(endDate)))
        .get();

    // 6. Fetch Expenses
    final expenses = await (db.select(db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startDate) &
              tbl.occurredAt.isSmallerOrEqualValue(endDate)))
        .get();

    // Map metrics by normalized day
    final Map<DateTime, int> studyByDay = {};
    for (final s in studySessions) {
      final key = normalizeDate(s.startedAt);
      studyByDay[key] = (studyByDay[key] ?? 0) + (s.actualSeconds ~/ 60);
    }

    final Map<DateTime, int> screenByDay = {};
    for (final st in screenSnapshots) {
      final key = normalizeDate(st.date);
      screenByDay[key] = (screenByDay[key] ?? 0) + st.durationMinutes;
    }

    final Map<DateTime, double> waterByDay = {};
    for (final w in waterEntries) {
      final key = normalizeDate(w.occurredAt);
      waterByDay[key] = (waterByDay[key] ?? 0.0) + w.value;
    }

    final Map<DateTime, double> movementByDay = {};
    for (final r in routes) {
      final key = normalizeDate(r.startTime);
      movementByDay[key] = (movementByDay[key] ?? 0.0) + r.totalDistanceMeters;
    }

    final Map<DateTime, int> completionsByDay = {};
    for (final c in completions) {
      final key = normalizeDate(c.completedAt);
      completionsByDay[key] = (completionsByDay[key] ?? 0) + 1;
    }

    final Map<DateTime, double> expensesByDay = {};
    for (final exp in expenses) {
      final key = normalizeDate(exp.occurredAt);
      expensesByDay[key] = (expensesByDay[key] ?? 0.0) + exp.amount;
    }

    // Build timeline of daily metrics
    final List<DailyDomainMetrics> dailyList = [];
    int activeDays = 0;

    for (int i = 0; i < days; i++) {
      final currentDay = startDate.add(Duration(days: i));
      final study = studyByDay[currentDay] ?? 0;
      final screen = screenByDay[currentDay] ?? 0;
      final water = waterByDay[currentDay] ?? 0.0;
      final movement = movementByDay[currentDay] ?? 0.0;
      final doneItems = completionsByDay[currentDay] ?? 0;
      final routineRate = (doneItems / totalRoutineItemsPerDay).clamp(0.0, 1.0);
      final expense = expensesByDay[currentDay] ?? 0.0;

      final snapshot = DailyDomainMetrics(
        date: currentDay,
        studyMinutes: study,
        screenTimeMinutes: screen,
        waterGlasses: water,
        movementMeters: movement,
        routineCompletionRate: routineRate,
        expenseAmount: expense,
      );

      if (snapshot.hasAnyActivity) {
        activeDays++;
      }
      dailyList.add(snapshot);
    }

    // Calculate Cross-Domain Insights
    final insights = _computeInsights(dailyList, activeDays);

    LifeInsight? strongest;
    if (insights.isNotEmpty) {
      strongest = insights.reduce(
        (a, b) => a.contrastPercent.abs() >= b.contrastPercent.abs() ? a : b,
      );
    }

    final completeness = days > 0 ? (activeDays / days).clamp(0.0, 1.0) : 0.0;

    return IntelligenceReport(
      daysAnalyzed: days,
      activeDaysCount: activeDays,
      dailyMetrics: dailyList,
      insights: insights,
      strongestCorrelation: strongest,
      dataCompleteness: completeness,
    );
  }

  /// Discovers behavioral contrasts and correlations across domains.
  List<LifeInsight> _computeInsights(
    List<DailyDomainMetrics> metrics,
    int activeDays,
  ) {
    final List<LifeInsight> results = [];
    if (activeDays < 2) return results;

    // Filter to active days for statistical evaluation
    final activeMetrics = metrics.where((m) => m.hasAnyActivity).toList();

    // 1. Focus vs Screen Time Correlation
    final focusDays = activeMetrics.where((m) => m.studyMinutes > 0 || m.screenTimeMinutes > 0).toList();
    if (focusDays.length >= 2) {
      final highStudyDays = focusDays.where((m) => m.studyMinutes >= 45).toList();
      final lowStudyDays = focusDays.where((m) => m.studyMinutes < 45).toList();

      if (highStudyDays.isNotEmpty && lowStudyDays.isNotEmpty) {
        final avgScreenHigh = _meanInt(highStudyDays.map((m) => m.screenTimeMinutes));
        final avgScreenLow = _meanInt(lowStudyDays.map((m) => m.screenTimeMinutes));

        if (avgScreenLow > 0) {
          final diffPercent = ((avgScreenHigh - avgScreenLow) / avgScreenLow) * 100;
          final r = _calculatePearson(
            focusDays.map((m) => m.studyMinutes.toDouble()).toList(),
            focusDays.map((m) => m.screenTimeMinutes.toDouble()).toList(),
          );

          final isDrop = diffPercent < 0;
          final absDiff = diffPercent.abs().toStringAsFixed(0);

          results.add(
            LifeInsight(
              id: 'focus_screen_time',
              category: InsightCategory.focusVsScreenTime,
              title: 'Deep Work & Screen Time',
              headline: isDrop
                  ? 'Deep work sessions reduce daily screen time by $absDiff%'
                  : 'Screen time varies by $absDiff% on focused study days',
              description:
                  'On days with 45+ minutes of study, screen time averages ${avgScreenHigh.toStringAsFixed(0)}m compared to ${avgScreenLow.toStringAsFixed(0)}m on lower focus days.',
              recommendation:
                  'Starting your day with a 25-minute Pomodoro block naturally curbs screen distraction before it starts.',
              correlationCoefficient: r,
              contrastPercent: diffPercent,
              highGroupLabel: 'Focus Days (45m+)',
              highGroupMetric: '${avgScreenHigh.toStringAsFixed(0)}m screen',
              lowGroupLabel: 'Low Focus Days',
              lowGroupMetric: '${avgScreenLow.toStringAsFixed(0)}m screen',
              sampleDays: focusDays.length,
              isStatisticallyMeaningful: focusDays.length >= 3 && diffPercent.abs() >= 10,
            ),
          );
        }
      }
    }

    // 2. Hydration vs Movement Correlation
    final movementHydrationDays = activeMetrics
        .where((m) => m.waterGlasses > 0 || m.movementMeters > 0)
        .toList();
    if (movementHydrationDays.length >= 2) {
      final highWaterDays = movementHydrationDays.where((m) => m.waterGlasses >= 6).toList();
      final lowWaterDays = movementHydrationDays.where((m) => m.waterGlasses < 6).toList();

      if (highWaterDays.isNotEmpty && lowWaterDays.isNotEmpty) {
        final avgMoveHigh = _meanDouble(highWaterDays.map((m) => m.movementMeters));
        final avgMoveLow = _meanDouble(lowWaterDays.map((m) => m.movementMeters));

        if (avgMoveLow > 0) {
          final diffPercent = ((avgMoveHigh - avgMoveLow) / avgMoveLow) * 100;
          final r = _calculatePearson(
            movementHydrationDays.map((m) => m.waterGlasses).toList(),
            movementHydrationDays.map((m) => m.movementMeters).toList(),
          );

          final highKm = (avgMoveHigh / 1000).toStringAsFixed(1);
          final lowKm = (avgMoveLow / 1000).toStringAsFixed(1);
          final absDiff = diffPercent.abs().toStringAsFixed(0);

          results.add(
            LifeInsight(
              id: 'hydration_movement',
              category: InsightCategory.hydrationVsMovement,
              title: 'Hydration & Daily Mobility',
              headline: diffPercent >= 0
                  ? 'Optimal hydration correlates with +$absDiff% greater movement distance'
                  : 'Movement distance shifts by $absDiff% on hydrated days',
              description:
                  'Days with 6+ glasses of water average ${highKm}km of movement, compared to ${lowKm}km on lower hydration days.',
              recommendation:
                  'Log your first two glasses of water within 30 minutes of waking to prime daily energy.',
              correlationCoefficient: r,
              contrastPercent: diffPercent,
              highGroupLabel: 'Hydrated (6+ glasses)',
              highGroupMetric: '${highKm}km movement',
              lowGroupLabel: 'Low Hydration',
              lowGroupMetric: '${lowKm}km movement',
              sampleDays: movementHydrationDays.length,
              isStatisticallyMeaningful: movementHydrationDays.length >= 3 && diffPercent.abs() >= 10,
            ),
          );
        }
      }
    }

    // 3. Screen Time vs Next-Day Routine Completion
    if (metrics.length >= 2) {
      final List<MapEntry<int, double>> transitions = [];
      for (int i = 0; i < metrics.length - 1; i++) {
        final todayScreen = metrics[i].screenTimeMinutes;
        final nextDayRoutines = metrics[i + 1].routineCompletionRate;
        if (todayScreen > 0 || nextDayRoutines > 0) {
          transitions.add(MapEntry(todayScreen, nextDayRoutines));
        }
      }

      if (transitions.length >= 2) {
        final highScreenPrev = transitions.where((t) => t.key >= 150).toList();
        final lowScreenPrev = transitions.where((t) => t.key < 150).toList();

        if (highScreenPrev.isNotEmpty && lowScreenPrev.isNotEmpty) {
          final avgRoutineAfterHigh = _meanDouble(highScreenPrev.map((t) => t.value));
          final avgRoutineAfterLow = _meanDouble(lowScreenPrev.map((t) => t.value));

          if (avgRoutineAfterLow > 0) {
            final diffPercent = ((avgRoutineAfterHigh - avgRoutineAfterLow) / avgRoutineAfterLow) * 100;
            final highPct = (avgRoutineAfterHigh * 100).toStringAsFixed(0);
            final lowPct = (avgRoutineAfterLow * 100).toStringAsFixed(0);
            final absDiff = diffPercent.abs().toStringAsFixed(0);

            results.add(
              LifeInsight(
                id: 'screentime_routines',
                category: InsightCategory.screenTimeVsRoutines,
                title: 'Screen Time & Next-Day Routines',
                headline: diffPercent < 0
                  ? 'High screen time days precede a $absDiff% drop in morning routine completion'
                  : 'Routine consistency shifts by $absDiff% following high screen time',
                description:
                    'Following days with 2.5h+ screen time, next-day routine completion averages $highPct%, versus $lowPct% after lower screen time days.',
                recommendation:
                    'Set a digital sunset 45 minutes before sleep to protect your next-morning consistency.',
                contrastPercent: diffPercent,
                highGroupLabel: 'After High Screen (150m+)',
                highGroupMetric: '$highPct% routines',
                lowGroupLabel: 'After Balanced Screen',
                lowGroupMetric: '$lowPct% routines',
                sampleDays: transitions.length,
                isStatisticallyMeaningful: transitions.length >= 3 && diffPercent.abs() >= 10,
              ),
            );
          }
        }
      }
    }

    // 4. Focus vs Financial Impulse (Study vs Expenses)
    final studyExpenseDays = activeMetrics
        .where((m) => m.studyMinutes > 0 || m.expenseAmount > 0)
        .toList();
    if (studyExpenseDays.length >= 2) {
      final highStudyDays = studyExpenseDays.where((m) => m.studyMinutes >= 30).toList();
      final noStudyDays = studyExpenseDays.where((m) => m.studyMinutes < 30).toList();

      if (highStudyDays.isNotEmpty && noStudyDays.isNotEmpty) {
        final avgExpenseStudy = _meanDouble(highStudyDays.map((m) => m.expenseAmount));
        final avgExpenseNoStudy = _meanDouble(noStudyDays.map((m) => m.expenseAmount));

        if (avgExpenseNoStudy > 0) {
          final diffPercent = ((avgExpenseStudy - avgExpenseNoStudy) / avgExpenseNoStudy) * 100;
          final studySpent = avgExpenseStudy.toStringAsFixed(0);
          final noStudySpent = avgExpenseNoStudy.toStringAsFixed(0);
          final absDiff = diffPercent.abs().toStringAsFixed(0);

          results.add(
            LifeInsight(
              id: 'focus_spending',
              category: InsightCategory.focusVsSpending,
              title: 'Deep Work & Spending Discipline',
              headline: diffPercent < 0
                  ? 'Active study days reduce daily spending by $absDiff%'
                  : 'Spending contrasts by $absDiff% on study vs leisure days',
              description:
                  'Daily spending averages \$$studySpent on days with focused study blocks, compared to \$$noStudySpent on low study days.',
              recommendation:
                  'When tempted by impulsive purchases, redirect your focus to a 20-minute study session to reset dopamine levels.',
              contrastPercent: diffPercent,
              highGroupLabel: 'Study Days (30m+)',
              highGroupMetric: '\$$studySpent daily',
              lowGroupLabel: 'Low Study Days',
              lowGroupMetric: '\$$noStudySpent daily',
              sampleDays: studyExpenseDays.length,
              isStatisticallyMeaningful: studyExpenseDays.length >= 3 && diffPercent.abs() >= 10,
            ),
          );
        }
      }
    }

    return results;
  }

  /// Computes Pearson correlation coefficient between two numeric vectors.
  double? _calculatePearson(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 3) return null;
    final n = x.length;

    final xMean = x.reduce((a, b) => a + b) / n;
    final yMean = y.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double xSq = 0.0;
    double ySq = 0.0;

    for (int i = 0; i < n; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;
      numerator += xDiff * yDiff;
      xSq += xDiff * xDiff;
      ySq += yDiff * yDiff;
    }

    final denominator = sqrt(xSq * ySq);
    if (denominator == 0.0) return null;

    final r = numerator / denominator;
    return r.clamp(-1.0, 1.0);
  }

  double _meanInt(Iterable<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _meanDouble(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
