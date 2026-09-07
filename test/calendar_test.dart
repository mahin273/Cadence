import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/calendar/models/calendar_models.dart';
import 'package:cadence/features/calendar/providers/calendar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarController & Database Operations', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-calendar-user';

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => testUserId),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('createEvent persists calendar event with correct timestamps, category and sync flags', () async {
      final controller = container.read(calendarControllerProvider);
      final startTime = DateTime(2026, 9, 8, 10, 0);
      final endTime = DateTime(2026, 9, 8, 11, 30);

      final eventId = await controller.createEvent(
        title: 'Deep Architecture Work',
        description: 'Review schema migrations and indexes',
        startTime: startTime,
        endTime: endTime,
        category: 'work',
      );

      final allEvents = await db.watchAllEvents(testUserId).first;
      expect(allEvents.length, 1);
      final event = allEvents.first;
      expect(event.id, eventId);
      expect(event.userId, testUserId);
      expect(event.title, 'Deep Architecture Work');
      expect(event.description, 'Review schema migrations and indexes');
      expect(event.startTime.isAtSameMomentAs(startTime), isTrue);
      expect(event.endTime.isAtSameMomentAs(endTime), isTrue);
      expect(event.category, 'work');
      expect(event.isAllDay, isFalse);
      expect(event.isDeleted, isFalse);
      expect(event.isSynced, isFalse);
    });

    test('updateEvent modifies title, category, and timestamps', () async {
      final controller = container.read(calendarControllerProvider);
      final initialStart = DateTime(2026, 9, 8, 14, 0);
      final initialEnd = DateTime(2026, 9, 8, 15, 0);

      final eventId = await controller.createEvent(
        title: 'Drafting Specs',
        startTime: initialStart,
        endTime: initialEnd,
        category: 'study',
      );

      final updatedStart = DateTime(2026, 9, 8, 15, 0);
      final updatedEnd = DateTime(2026, 9, 8, 16, 30);

      await controller.updateEvent(
        id: eventId,
        title: 'Completed Specs & Review',
        description: 'Updated with review feedback',
        startTime: updatedStart,
        endTime: updatedEnd,
        category: 'work',
        isAllDay: false,
      );

      final events = await db.watchAllEvents(testUserId).first;
      expect(events.length, 1);
      expect(events.first.title, 'Completed Specs & Review');
      expect(events.first.description, 'Updated with review feedback');
      expect(events.first.category, 'work');
      expect(events.first.startTime.isAtSameMomentAs(updatedStart), isTrue);
      expect(events.first.endTime.isAtSameMomentAs(updatedEnd), isTrue);
    });

    test('deleteEvent soft-deletes event and marks unsynced', () async {
      final controller = container.read(calendarControllerProvider);
      final eventId = await controller.createEvent(
        title: 'Temporary Reminder',
        startTime: DateTime(2026, 9, 8, 9, 0),
        endTime: DateTime(2026, 9, 8, 9, 30),
      );

      // Active events should have 1
      var activeEvents = await db.watchAllEvents(testUserId).first;
      expect(activeEvents.length, 1);

      await controller.deleteEvent(eventId);

      // Active events should now be 0
      activeEvents = await db.watchAllEvents(testUserId).first;
      expect(activeEvents.isEmpty, isTrue);

      // Underlying table contains soft-deleted record
      final rawRow = await (db.select(db.calendarEvents)..where((tbl) => tbl.id.equals(eventId))).getSingle();
      expect(rawRow.isDeleted, isTrue);
      expect(rawRow.isSynced, isFalse);
    });

    test('watchEventsForDay returns events on selected day and handles midnight spans', () async {
      final controller = container.read(calendarControllerProvider);
      final targetDay = DateTime(2026, 9, 8);

      // Event 1: Entirely within today (10:00 - 11:00)
      await controller.createEvent(
        title: 'Morning Sync',
        startTime: DateTime(2026, 9, 8, 10, 0),
        endTime: DateTime(2026, 9, 8, 11, 0),
      );

      // Event 2: Starts today, ends tomorrow (23:00 Sep 8 - 02:00 Sep 9)
      await controller.createEvent(
        title: 'Late Night Hack',
        startTime: DateTime(2026, 9, 8, 23, 0),
        endTime: DateTime(2026, 9, 9, 2, 0),
      );

      // Event 3: Strictly on yesterday (Sep 7)
      await controller.createEvent(
        title: 'Yesterday Task',
        startTime: DateTime(2026, 9, 7, 14, 0),
        endTime: DateTime(2026, 9, 7, 15, 0),
      );

      // Event 4: Strictly tomorrow afternoon (Sep 9 14:00 - 15:00)
      await controller.createEvent(
        title: 'Tomorrow Meeting',
        startTime: DateTime(2026, 9, 9, 14, 0),
        endTime: DateTime(2026, 9, 9, 15, 0),
      );

      // Watch events for Sep 8: should contain Event 1 and Event 2 (overlapping midnight)
      final dayEvents = await db.watchEventsForDay(testUserId, targetDay).first;
      expect(dayEvents.length, 2);
      final titles = dayEvents.map((e) => e.title).toList();
      expect(titles, contains('Morning Sync'));
      expect(titles, contains('Late Night Hack'));
      expect(titles, isNot(contains('Yesterday Task')));
      expect(titles, isNot(contains('Tomorrow Meeting')));

      // Watch events for Sep 9: should contain Event 2 (Late Night Hack) and Event 4 (Tomorrow Meeting)
      final nextDayEvents = await db.watchEventsForDay(testUserId, DateTime(2026, 9, 9)).first;
      expect(nextDayEvents.length, 2);
      final nextTitles = nextDayEvents.map((e) => e.title).toList();
      expect(nextTitles, contains('Late Night Hack'));
      expect(nextTitles, contains('Tomorrow Meeting'));
    });

    test('watchEventsForRange aggregates 7-day week events correctly', () async {
      final controller = container.read(calendarControllerProvider);
      final selectedDate = DateTime(2026, 9, 8); // Tuesday
      final mondayLocal = getStartOfWeek(selectedDate);
      final sundayLocal = mondayLocal.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

      // Monday Sep 7
      await controller.createEvent(
        title: 'Mon Event',
        startTime: DateTime(2026, 9, 7, 9, 0),
        endTime: DateTime(2026, 9, 7, 10, 0),
      );

      // Wednesday Sep 9
      await controller.createEvent(
        title: 'Wed Event',
        startTime: DateTime(2026, 9, 9, 12, 0),
        endTime: DateTime(2026, 9, 9, 13, 0),
      );

      // Sunday Sep 13
      await controller.createEvent(
        title: 'Sun Event',
        startTime: DateTime(2026, 9, 13, 18, 0),
        endTime: DateTime(2026, 9, 13, 19, 0),
      );

      // Next Monday Sep 14 (out of this week)
      await controller.createEvent(
        title: 'Next Week Event',
        startTime: DateTime(2026, 9, 14, 9, 0),
        endTime: DateTime(2026, 9, 14, 10, 0),
      );

      final weekEvents = await db.watchEventsForRange(
        testUserId,
        mondayLocal.toUtc(),
        sundayLocal.toUtc(),
      ).first;

      expect(weekEvents.length, 3);
      final titles = weekEvents.map((e) => e.title).toList();
      expect(titles, contains('Mon Event'));
      expect(titles, contains('Wed Event'));
      expect(titles, contains('Sun Event'));
      expect(titles, isNot(contains('Next Week Event')));
    });

    test('SelectedDateNotifier navigates next, prev week and jumps to today', () {
      final notifier = container.read(selectedDateProvider.notifier);
      final initial = container.read(selectedDateProvider);

      notifier.nextWeek();
      expect(container.read(selectedDateProvider), initial.add(const Duration(days: 7)));

      notifier.prevWeek();
      expect(container.read(selectedDateProvider), initial);

      notifier.setDate(DateTime(2030, 1, 1));
      expect(container.read(selectedDateProvider), DateTime(2030, 1, 1));

      notifier.jumpToToday();
      final now = DateTime.now();
      expect(container.read(selectedDateProvider).day, now.day);
      expect(container.read(selectedDateProvider).month, now.month);
      expect(container.read(selectedDateProvider).year, now.year);
    });

    test('CalendarViewModeNotifier toggles view modes', () {
      final notifier = container.read(calendarViewModeProvider.notifier);
      expect(container.read(calendarViewModeProvider), CalendarViewMode.day);

      notifier.setMode(CalendarViewMode.week);
      expect(container.read(calendarViewModeProvider), CalendarViewMode.week);

      notifier.setMode(CalendarViewMode.day);
      expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
    });
  });
}
