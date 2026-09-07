import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../models/weekly_summary_data.dart';
import '../services/weekly_aggregation_service.dart';

/// Provider for the aggregation service instance.
final weeklyAggregationServiceProvider =
    Provider<WeeklyAggregationService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return WeeklyAggregationService(db);
});

/// State notifier managing the currently viewed week's reference date.
class SelectedReviewWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return WeeklyAggregationService.startOfWeek(now);
  }

  void previousWeek() {
    state = state.subtract(const Duration(days: 7));
  }

  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }

  void selectDate(DateTime date) {
    state = WeeklyAggregationService.startOfWeek(date);
  }

  void resetToCurrentWeek() {
    final now = DateTime.now();
    state = WeeklyAggregationService.startOfWeek(now);
  }
}

final selectedReviewWeekProvider =
    NotifierProvider<SelectedReviewWeekNotifier, DateTime>(
  SelectedReviewWeekNotifier.new,
);

/// Computes fresh aggregation metrics for any requested week.
final weeklySummaryProvider =
    FutureProvider.family<WeeklySummaryData, DateTime>((ref, date) async {
  final service = ref.watch(weeklyAggregationServiceProvider);
  return service.aggregateWeek(date);
});

/// Streams persisted review snapshot and reflection notes for a given week.
final savedWeeklyReviewProvider =
    StreamProvider.family<WeeklyReview?, DateTime>((ref, date) {
  final service = ref.watch(weeklyAggregationServiceProvider);
  return service.watchSavedReview(date);
});

/// Controller for persisting reviews and reflections.
class WeeklyReviewController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<String?> saveReview({
    required WeeklySummaryData summary,
    String? reflectionNotes,
    String? userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(weeklyAggregationServiceProvider);
      final id = await service.saveReviewSnapshot(
        summary: summary,
        reflectionNotes: reflectionNotes,
        userId: userId,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteReview(String id) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.deleteWeeklyReview(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final weeklyReviewControllerProvider =
    NotifierProvider<WeeklyReviewController, AsyncValue<void>>(
  WeeklyReviewController.new,
);
