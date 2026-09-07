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

  group('TimeConflictDetector & Time-Blocking Logic', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-timeblock-user';

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

    test('detectConflicts flags intersecting intervals and ignores abutting intervals', () {
      final base = DateTime(2026, 9, 8);

      final event1 = CalendarEvent(
        id: 'event-1',
        userId: testUserId,
        title: 'Deep Work Block 1',
        startTime: DateTime(base.year, base.month, base.day, 9, 0),
        endTime: DateTime(base.year, base.month, base.day, 10, 30),
        isAllDay: false,
        category: 'work',
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      // Event 2 overlaps with Event 1 (10:00 to 11:00 overlaps from 10:00 to 10:30)
      final event2 = CalendarEvent(
        id: 'event-2',
        userId: testUserId,
        title: 'Meeting Conflict',
        startTime: DateTime(base.year, base.month, base.day, 10, 0),
        endTime: DateTime(base.year, base.month, base.day, 11, 0),
        isAllDay: false,
        category: 'personal',
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      // Event 3 abuts Event 2 (11:00 to 12:00 -> exactly adjacent, NO conflict!)
      final event3 = CalendarEvent(
        id: 'event-3',
        userId: testUserId,
        title: 'Lunch Break',
        startTime: DateTime(base.year, base.month, base.day, 11, 0),
        endTime: DateTime(base.year, base.month, base.day, 12, 0),
        isAllDay: false,
        category: 'rest',
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final blocks = TimeConflictDetector.detectConflicts([event1, event2, event3]);
      expect(blocks.length, 3);

      final block1 = blocks.firstWhere((b) => b.event.id == 'event-1');
      final block2 = blocks.firstWhere((b) => b.event.id == 'event-2');
      final block3 = blocks.firstWhere((b) => b.event.id == 'event-3');

      // Block 1 and 2 conflict with each other
      expect(block1.hasConflict, isTrue);
      expect(block1.conflictingEventIds, contains('event-2'));

      expect(block2.hasConflict, isTrue);
      expect(block2.conflictingEventIds, contains('event-1'));

      // Block 3 does NOT conflict with any event
      expect(block3.hasConflict, isFalse);
      expect(block3.conflictingEventIds, isEmpty);
    });

    test('TimeBlockWithConflict calculates duration and minute offsets accurately', () {
      final base = DateTime(2026, 9, 8);
      final event = CalendarEvent(
        id: 'event-offset',
        userId: testUserId,
        title: 'Algorithms Lecture',
        startTime: DateTime(base.year, base.month, base.day, 14, 15),
        endTime: DateTime(base.year, base.month, base.day, 15, 45),
        isAllDay: false,
        category: 'study',
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final block = TimeBlockWithConflict(event: event);
      expect(block.durationMinutes, 90);
      expect(block.startMinutesFromMidnight, 14 * 60 + 15); // 855 mins
      expect(block.endMinutesFromMidnight, 15 * 60 + 45); // 945 mins
    });

    test('CalendarController creates routine and movement blocks', () async {
      final controller = container.read(calendarControllerProvider);
      final start = DateTime(2026, 9, 8, 7, 0);
      final end = DateTime(2026, 9, 8, 8, 0);

      final eventId = await controller.createEvent(
        title: 'Morning Routine Priming',
        category: 'routine',
        startTime: start,
        endTime: end,
      );

      final events = await db.watchEventsForDay(testUserId, start).first;
      expect(events.length, 1);
      final created = events.first;
      expect(created.id, eventId);
      expect(created.category, 'routine');
      expect(created.title, 'Morning Routine Priming');
    });
  });
}
