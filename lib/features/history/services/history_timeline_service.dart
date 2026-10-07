import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../models/day_history_models.dart';

/// Aggregation and search engine for historical dates and multi-domain activities.
class HistoryTimelineService {
  final AppDatabase db;

  HistoryTimelineService(this.db);

  /// Fetch all activities for a given calendar date organized into a chronological timeline.
  Future<DayHistorySummary> getDayHistory(DateTime targetDate) async {
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

    final List<DayTimelineEvent> events = [];

    // 1. Study Sessions
    final studySessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(startOfDay) &
              tbl.startedAt.isSmallerOrEqualValue(endOfDay)))
        .get();

    int totalStudyMinutes = 0;
    for (final s in studySessions) {
      final mins = s.actualSeconds ~/ 60;
      if (s.sessionType == 'work') {
        totalStudyMinutes += mins;
      }
      events.add(
        DayTimelineEvent(
          id: 'study_${s.id}',
          timestamp: s.startedAt,
          title: 'Focus: ${s.subject}',
          subtitle: '${mins}m duration (${s.sessionType})',
          eventType: TimelineEventType.study,
          metricValue: '${mins}m',
          tag: s.tag,
        ),
      );
    }

    // 2. GPS Movement Routes
    final routes = await (db.select(db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startOfDay) &
              tbl.startTime.isSmallerOrEqualValue(endOfDay)))
        .get();

    double totalMovementMeters = 0.0;
    for (final r in routes) {
      totalMovementMeters += r.totalDistanceMeters;
      final km = (r.totalDistanceMeters / 1000).toStringAsFixed(2);
      final durationMins = r.durationSeconds ~/ 60;
      events.add(
        DayTimelineEvent(
          id: 'route_${r.id}',
          timestamp: r.startTime,
          title: r.title,
          subtitle: '${km}km distance in ${durationMins}m',
          eventType: TimelineEventType.movement,
          metricValue: '${km}km',
        ),
      );
    }

    // 3. Entries (Water, Habits, Mood, Journal)
    final entries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerOrEqualValue(endOfDay) &
              tbl.isDeleted.equals(false)))
        .get();

    double totalWaterGlasses = 0.0;
    for (final e in entries) {
      if (e.type == 'water') {
        totalWaterGlasses += e.value;
        events.add(
          DayTimelineEvent(
            id: 'entry_${e.id}',
            timestamp: e.occurredAt,
            title: 'Water Intake',
            subtitle: '${e.value.toStringAsFixed(0)} glasses logged',
            eventType: TimelineEventType.water,
            metricValue: '${e.value.toStringAsFixed(0)} gl',
          ),
        );
      } else {
        final tagsLabel = e.tags.isNotEmpty ? e.tags.join(', ') : null;
        events.add(
          DayTimelineEvent(
            id: 'entry_${e.id}',
            timestamp: e.occurredAt,
            title: e.note != null && e.note!.isNotEmpty
                ? e.note!
                : '${e.type.toUpperCase()} Logged',
            subtitle: tagsLabel,
            eventType: TimelineEventType.habit,
            metricValue: e.value > 0 ? e.value.toStringAsFixed(1) : null,
          ),
        );
      }
    }

    // 4. Expenses
    final expenses = await (db.select(db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerOrEqualValue(endOfDay)))
        .get();

    double totalExpenses = 0.0;
    for (final exp in expenses) {
      totalExpenses += exp.amount;
      events.add(
        DayTimelineEvent(
          id: 'expense_${exp.id}',
          timestamp: exp.occurredAt,
          title: 'Expense: ${exp.category}',
          subtitle: exp.note,
          eventType: TimelineEventType.expense,
          metricValue: '\$${exp.amount.toStringAsFixed(2)}',
        ),
      );
    }

    // 5. Routine Completions
    final completions = await (db.select(db.routineCompletions)
          ..where((tbl) =>
              tbl.completedAt.isBiggerOrEqualValue(startOfDay) &
              tbl.completedAt.isSmallerOrEqualValue(endOfDay)))
        .get();

    final routineItems = await db.select(db.routineItems).get();
    final routineItemMap = {for (final item in routineItems) item.id: item.title};

    for (final c in completions) {
      final itemTitle = routineItemMap[c.itemId] ?? 'Routine Task';
      events.add(
        DayTimelineEvent(
          id: 'routine_${c.id}',
          timestamp: c.completedAt,
          title: itemTitle,
          subtitle: 'Completed routine item',
          eventType: TimelineEventType.routine,
        ),
      );
    }

    // 6. Calendar Events
    final calendarEvents = await (db.select(db.calendarEvents)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startOfDay) &
              tbl.startTime.isSmallerOrEqualValue(endOfDay)))
        .get();

    for (final ev in calendarEvents) {
      events.add(
        DayTimelineEvent(
          id: 'event_${ev.id}',
          timestamp: ev.startTime,
          title: ev.title,
          subtitle: ev.description,
          eventType: TimelineEventType.calendarEvent,
        ),
      );
    }

    // Sort chronologically ascending (earliest to latest in the day)
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return DayHistorySummary(
      date: startOfDay,
      events: events,
      totalStudyMinutes: totalStudyMinutes,
      totalMovementDistanceMeters: totalMovementMeters,
      totalWaterGlasses: totalWaterGlasses,
      totalExpenses: totalExpenses,
      routinesCompletedCount: completions.length,
    );
  }

  /// Global search across all historical database tables.
  Future<List<UniversalSearchResult>> searchAcrossAllDomains(
    String rawQuery, {
    TimelineEventType? filterType,
    int limit = 60,
  }) async {
    final query = rawQuery.trim().toLowerCase();
    final List<UniversalSearchResult> results = [];

    // Search Entries (Notes, Tags, Types)
    if (filterType == null ||
        filterType == TimelineEventType.habit ||
        filterType == TimelineEventType.water) {
      final entries = await (db.select(db.entries)
            ..where((tbl) => tbl.isDeleted.equals(false)))
          .get();

      for (final e in entries) {
        final noteMatch = e.note?.toLowerCase().contains(query) ?? false;
        final typeMatch = e.type.toLowerCase().contains(query);
        final tagMatch = e.tags.any((t) => t.toLowerCase().contains(query));

        if (query.isEmpty || noteMatch || typeMatch || tagMatch) {
          final isWater = e.type == 'water';
          if (filterType == null ||
              (filterType == TimelineEventType.water && isWater) ||
              (filterType == TimelineEventType.habit && !isWater)) {
            results.add(
              UniversalSearchResult(
                id: 'entry_${e.id}',
                title: isWater
                    ? 'Water (${e.value.toStringAsFixed(0)} glasses)'
                    : (e.note ?? '${e.type.toUpperCase()} Log'),
                subtitle: e.tags.isNotEmpty ? e.tags.join(', ') : e.type,
                type: isWater ? TimelineEventType.water : TimelineEventType.habit,
                occurredAt: e.occurredAt,
                metricValue: isWater ? '${e.value.toStringAsFixed(0)} glasses' : null,
              ),
            );
          }
        }
      }
    }

    // Search Expenses
    if (filterType == null || filterType == TimelineEventType.expense) {
      final expenses = await db.select(db.expenses).get();
      for (final exp in expenses) {
        final catMatch = exp.category.toLowerCase().contains(query);
        final noteMatch = exp.note?.toLowerCase().contains(query) ?? false;
        final tagMatch = exp.tags.any((t) => t.toLowerCase().contains(query));

        if (query.isEmpty || catMatch || noteMatch || tagMatch) {
          results.add(
            UniversalSearchResult(
              id: 'expense_${exp.id}',
              title: '\$${exp.amount.toStringAsFixed(2)} - ${exp.category}',
              subtitle: exp.note ?? exp.category,
              type: TimelineEventType.expense,
              occurredAt: exp.occurredAt,
              metricValue: '\$${exp.amount.toStringAsFixed(2)}',
            ),
          );
        }
      }
    }

    // Search Study Sessions
    if (filterType == null || filterType == TimelineEventType.study) {
      final sessions = await db.select(db.studySessions).get();
      for (final s in sessions) {
        final subjMatch = s.subject.toLowerCase().contains(query);
        final tagMatch = s.tag?.toLowerCase().contains(query) ?? false;

        if (query.isEmpty || subjMatch || tagMatch) {
          final mins = s.actualSeconds ~/ 60;
          results.add(
            UniversalSearchResult(
              id: 'study_${s.id}',
              title: s.subject,
              subtitle: '${mins}m focus session',
              type: TimelineEventType.study,
              occurredAt: s.startedAt,
              metricValue: '${mins}m',
              tag: s.tag,
            ),
          );
        }
      }
    }

    // Search Movement Routes
    if (filterType == null || filterType == TimelineEventType.movement) {
      final routes = await db.select(db.routes).get();
      for (final r in routes) {
        final titleMatch = r.title.toLowerCase().contains(query);
        final typeMatch = r.activityType.toLowerCase().contains(query);

        if (query.isEmpty || titleMatch || typeMatch) {
          final km = (r.totalDistanceMeters / 1000).toStringAsFixed(2);
          results.add(
            UniversalSearchResult(
              id: 'route_${r.id}',
              title: r.title,
              subtitle: '${km}km ${r.activityType}',
              type: TimelineEventType.movement,
              occurredAt: r.startTime,
              metricValue: '${km}km',
            ),
          );
        }
      }
    }

    // Sort newest first
    results.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Get distinct days of the month that have activity records (for calendar dots).
  Future<Set<int>> getActiveDaysInMonth(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final Set<int> activeDays = {};

    final study = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(startOfMonth) &
              tbl.startedAt.isSmallerOrEqualValue(endOfMonth)))
        .get();
    for (final s in study) {
      activeDays.add(s.startedAt.day);
    }

    final routes = await (db.select(db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startOfMonth) &
              tbl.startTime.isSmallerOrEqualValue(endOfMonth)))
        .get();
    for (final r in routes) {
      activeDays.add(r.startTime.day);
    }

    final entries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfMonth) &
              tbl.occurredAt.isSmallerOrEqualValue(endOfMonth) &
              tbl.isDeleted.equals(false)))
        .get();
    for (final e in entries) {
      activeDays.add(e.occurredAt.day);
    }

    final expenses = await (db.select(db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfMonth) &
              tbl.occurredAt.isSmallerOrEqualValue(endOfMonth)))
        .get();
    for (final exp in expenses) {
      activeDays.add(exp.occurredAt.day);
    }

    return activeDays;
  }
}
