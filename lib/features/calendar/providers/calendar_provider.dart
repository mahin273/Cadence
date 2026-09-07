import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../models/calendar_models.dart';

/// Notifier managing currently selected date in the calendar / planner view.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }

  void prevWeek() {
    state = state.subtract(const Duration(days: 7));
  }

  void jumpToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

/// Provider for the currently selected calendar date.
final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(
  () => SelectedDateNotifier(),
);

/// Notifier managing current calendar display mode (Day vs Week).
class CalendarViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.day;

  void setMode(CalendarViewMode mode) {
    state = mode;
  }
}

/// Provider for the active calendar view mode.
final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeNotifier, CalendarViewMode>(
  () => CalendarViewModeNotifier(),
);

/// Helper to get the start of the week (Monday 00:00:00 local time).
DateTime getStartOfWeek(DateTime date) {
  final cleanDate = DateTime(date.year, date.month, date.day);
  return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
}

/// Stream provider for calendar events on the currently selected day.
final eventsForSelectedDateProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(activeUserIdProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  return db.watchEventsForDay(userId, selectedDate);
});

/// Stream provider for all calendar events spanning the current 7-day week window.
final eventsForWeekProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(activeUserIdProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  final mondayLocal = getStartOfWeek(selectedDate);
  final sundayLocal = mondayLocal.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

  return db.watchEventsForRange(
    userId,
    mondayLocal.toUtc(),
    sundayLocal.toUtc(),
  );
});

/// Controller to perform CRUD operations on CalendarEvents.
class CalendarController {
  final AppDatabase db;
  final String userId;

  CalendarController({required this.db, required this.userId});

  /// Create and persist a new calendar event.
  Future<String> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    int? colorValue,
    String category = 'personal',
  }) async {
    final eventId = const Uuid().v4();
    final now = DateTime.now().toUtc();

    final companion = CalendarEventsCompanion(
      id: Value(eventId),
      userId: Value(userId),
      title: Value(title.trim()),
      description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
      startTime: Value(startTime.toUtc()),
      endTime: Value(endTime.toUtc()),
      isAllDay: Value(isAllDay),
      colorValue: Value(colorValue),
      category: Value(category),
      isDeleted: const Value(false),
      isSynced: const Value(false),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await db.upsertCalendarEvent(companion);
    return eventId;
  }

  /// Update an existing calendar event.
  Future<void> updateEvent({
    required String id,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    int? colorValue,
    String category = 'personal',
  }) async {
    final now = DateTime.now().toUtc();

    final companion = CalendarEventsCompanion(
      id: Value(id),
      userId: Value(userId),
      title: Value(title.trim()),
      description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
      startTime: Value(startTime.toUtc()),
      endTime: Value(endTime.toUtc()),
      isAllDay: Value(isAllDay),
      colorValue: Value(colorValue),
      category: Value(category),
      isDeleted: const Value(false),
      isSynced: const Value(false),
      updatedAt: Value(now),
    );

    await db.updateCalendarEvent(id, companion);
  }

  /// Soft-delete a calendar event.
  Future<void> deleteEvent(String id) async {
    await db.softDeleteCalendarEvent(id);
  }
}

/// Provider exposing the CalendarController.
final calendarControllerProvider = Provider<CalendarController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(activeUserIdProvider);
  return CalendarController(db: db, userId: userId);
});
