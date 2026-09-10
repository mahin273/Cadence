import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/providers/screen_time_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../routines/providers/routines_provider.dart';
import '../../study/providers/pomodoro_provider.dart';

/// Aggregated "daily vitals" snapshot for the Today dashboard glance bar.
///
/// All fields default to zero so a fresh database renders `0m`, `$0.00`,
/// `0%` instead of null errors (Chunk 24 edge-case matrix).
class DailyVitalsSummary {
  final int screenTimeMinutes;
  final double todaySpent;
  final int focusMinutes;
  final int routinesCompleted;
  final int routinesTotal;

  const DailyVitalsSummary({
    this.screenTimeMinutes = 0,
    this.todaySpent = 0.0,
    this.focusMinutes = 0,
    this.routinesCompleted = 0,
    this.routinesTotal = 0,
  });

  double get routinesProgress =>
      routinesTotal == 0 ? 0.0 : (routinesCompleted / routinesTotal).clamp(0.0, 1.0);
}

/// Pure helper: is [occurredAt] within the local calendar day of [now]?
bool isToday(DateTime occurredAt, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return !occurredAt.isBefore(start) && occurredAt.isBefore(end);
}

/// Pure helper: sum expenses whose [occurredAt] falls today.
double sumSpentToday<T>(
  List<T> items,
  DateTime Function(T) occurredAtOf,
  double Function(T) amountOf,
  DateTime now,
) {
  var total = 0.0;
  for (final item in items) {
    if (isToday(occurredAtOf(item), now)) total += amountOf(item);
  }
  return total;
}

/// Pure helper: time-of-day greeting used by the hero banner.
String greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'Good Morning';
  if (hour >= 12 && hour < 17) return 'Good Afternoon';
  if (hour >= 17 && hour < 22) return 'Good Evening';
  return 'Rest & Recovery';
}

/// Today's total spend derived from the reactive monthly expenses stream.
final todayExpensesTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final expenses = ref.watch(allExpensesStreamProvider).value ?? [];
  return sumSpentToday(expenses, (e) => e.occurredAt, (e) => e.amount, now);
});

/// Today's screen-time minutes from the reactive screen-time summary.
final todayScreenMinutesProvider = Provider<int>((ref) {
  final summaryAsync = ref.watch(screenTimeSummaryProvider);
  return summaryAsync.maybeWhen(
    data: (summary) => summary.totalMinutes,
    orElse: () => 0,
  );
});

/// Routine completion progress (completed items / total items) for today.
final routinesProgressProvider = Provider<({int completed, int total, double pct})>((ref) {
  final routines = ref.watch(routinesWithItemsStreamProvider).value ?? [];
  var completed = 0;
  var total = 0;
  for (final r in routines) {
    completed += r.completedCount;
    total += r.totalCount;
  }
  final pct = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
  return (completed: completed, total: total, pct: pct);
});

/// Combined vitals snapshot composing lightweight cross-module providers.
final todayVitalsSummaryProvider = Provider<DailyVitalsSummary>((ref) {
  final screenMinutes = ref.watch(todayScreenMinutesProvider);
  final spent = ref.watch(todayExpensesTotalProvider);
  final focusSeconds = ref.watch(todayStudyWorkSecondsProvider);
  final routines = ref.watch(routinesProgressProvider);
  return DailyVitalsSummary(
    screenTimeMinutes: screenMinutes,
    todaySpent: spent,
    focusMinutes: focusSeconds ~/ 60,
    routinesCompleted: routines.completed,
    routinesTotal: routines.total,
  );
});
