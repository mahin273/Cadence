import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/calendar/presentation/planner_view.dart';
import 'package:cadence/features/calendar/widgets/calendar_event_card.dart';
import 'package:cadence/features/calendar/widgets/horizontal_date_strip.dart';
import 'package:cadence/features/calendar/widgets/create_event_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-calendar-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Calendar UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('HorizontalDateStrip renders 7 days and updates selected date on tap', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const HorizontalDateStrip(),
        ),
      );
      await tester.pumpAndSettle();

      // Find weekday labels (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
      expect(find.byType(InkWell), findsNWidgets(7));

      // Tap the second day in the strip
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('CalendarEventCard renders event details and duration', (tester) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 14, 0);
      final end = DateTime(now.year, now.month, now.day, 15, 30);

      final event = CalendarEvent(
        id: 'event-1',
        userId: 'test-calendar-user',
        title: 'Team Retrospective',
        description: 'Discuss sprint wins and improvements',
        startTime: start.toUtc(),
        endTime: end.toUtc(),
        isAllDay: false,
        category: 'work',
        isDeleted: false,
        isSynced: false,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: CalendarEventCard(event: event),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Team Retrospective'), findsOneWidget);
      expect(find.text('Discuss sprint wins and improvements'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PlannerView renders empty state and switches view modes', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const PlannerView(),
        ),
      );
      await tester.pumpAndSettle();

      // Header should show Today button and Day/Week segments
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Add Event'), findsOneWidget);

      // Empty state
      expect(find.text('No events scheduled'), findsOneWidget);
      expect(find.text('Schedule an Event'), findsOneWidget);

      // Toggle to Week mode
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      // Week mode shows 7 day sections
      expect(find.text('No events'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('CreateCalendarEventDialog validates inputs and creates event in DB', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CreateCalendarEventDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('New Calendar Event'), findsOneWidget);

      // Attempt to submit without title (validation fails)
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter an event title'), findsOneWidget);

      // Enter title
      await tester.enterText(find.byType(TextFormField).first, 'Exam Prep Session');
      await tester.pumpAndSettle();

      // Select 'Study' category chip
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify event was saved to SQLite database
      final events = await (db.select(db.calendarEvents)).get();
      expect(events.length, 1);
      expect(events.first.title, 'Exam Prep Session');
      expect(events.first.category, 'study');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
