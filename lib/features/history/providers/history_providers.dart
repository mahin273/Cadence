import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../models/day_history_models.dart';
import '../services/history_timeline_service.dart';

/// Provider for the history timeline service.
final historyTimelineServiceProvider = Provider<HistoryTimelineService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HistoryTimelineService(db);
});

/// State notifier for the currently selected history date.
class SelectedHistoryDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void selectDate(DateTime dt) {
    state = DateTime(dt.year, dt.month, dt.day);
  }

  void prevDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void nextDay() {
    state = state.add(const Duration(days: 1));
  }

  void resetToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final selectedHistoryDateProvider =
    NotifierProvider<SelectedHistoryDateNotifier, DateTime>(
  SelectedHistoryDateNotifier.new,
);

/// Reactive stream provider for the currently selected day's timeline history.
final dayHistoryProvider = StreamProvider<DayHistorySummary>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(historyTimelineServiceProvider);
  final targetDate = ref.watch(selectedHistoryDateProvider);

  yield await service.getDayHistory(targetDate);

  final updateStream = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.studySessions,
      db.routes,
      db.entries,
      db.expenses,
      db.routineCompletions,
      db.calendarEvents,
    ]),
  );

  await for (final _ in updateStream) {
    yield await service.getDayHistory(targetDate);
  }
});

/// Free-text search query notifier for universal search.
class HistorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
  void clear() => state = '';
}

final historySearchQueryProvider =
    NotifierProvider<HistorySearchQueryNotifier, String>(
  HistorySearchQueryNotifier.new,
);

/// Event type filter notifier for universal search.
class HistorySearchTypeFilterNotifier extends Notifier<TimelineEventType?> {
  @override
  TimelineEventType? build() => null;

  void setFilter(TimelineEventType? type) => state = type;
  void toggle(TimelineEventType type) => state = state == type ? null : type;
}

final historySearchTypeFilterProvider =
    NotifierProvider<HistorySearchTypeFilterNotifier, TimelineEventType?>(
  HistorySearchTypeFilterNotifier.new,
);

/// Reactive universal search results provider.
final universalSearchResultsProvider =
    StreamProvider<List<UniversalSearchResult>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(historyTimelineServiceProvider);
  final query = ref.watch(historySearchQueryProvider);
  final filter = ref.watch(historySearchTypeFilterProvider);

  yield await service.searchAcrossAllDomains(query, filterType: filter);

  final updateStream = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.studySessions,
      db.routes,
      db.entries,
      db.expenses,
      db.calendarEvents,
    ]),
  );

  await for (final _ in updateStream) {
    yield await service.searchAcrossAllDomains(query, filterType: filter);
  }
});

/// Provider for days in a month that have activity (for calendar picker badges).
final activeDaysInMonthProvider =
    FutureProvider.family<Set<int>, ({int year, int month})>((ref, arg) async {
  final service = ref.watch(historyTimelineServiceProvider);
  return service.getActiveDaysInMonth(arg.year, arg.month);
});
