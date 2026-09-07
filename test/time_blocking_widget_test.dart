import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/calendar/models/calendar_models.dart';
import 'package:cadence/features/calendar/presentation/planner_view.dart';
import 'package:cadence/features/calendar/widgets/time_block_tile.dart';
import 'package:cadence/features/calendar/widgets/time_blocking_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-timeblock-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Time-Blocking UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('TimeBlockTile renders title, duration and opens action modal on tap', (tester) async {
      final now = DateTime.now();
      final event = CalendarEvent(
        id: 'tb-1',
        userId: 'test-timeblock-user',
        title: 'Deep Architecture Sprint',
        description: 'Design time-blocking state machine',
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        endTime: DateTime(now.year, now.month, now.day, 12, 0),
        isAllDay: false,
        category: 'work',
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      );

      final block = TimeBlockWithConflict(
        event: event,
        hasConflict: true,
        conflictingEventIds: ['tb-conflict'],
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: TimeBlockTile(
            block: block,
            width: 250.0,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Deep Architecture Sprint'), findsOneWidget);
      expect(find.textContaining('120m'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      // Tap block to open detail sheet
      await tester.tap(find.text('Deep Architecture Sprint'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DEEP WORK'), findsOneWidget);
      expect(find.text('Time Conflict'), findsOneWidget);
      expect(find.text('Start Focus Session for This Block'), findsOneWidget);
      expect(find.text('Delete Time Block'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('TimeBlockingTimeline renders template chips and hour markers', (tester) async {
      final today = DateTime.now();

      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: TimeBlockingTimeline(selectedDate: today),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+ Deep Work (2h)'), findsOneWidget);
      expect(find.text('+ Study Session (1h)'), findsOneWidget);
      expect(find.text('+ Routine Block (30m)'), findsOneWidget);
      expect(find.text('+ Movement / Run (45m)'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PlannerView switches between Day, Blocks, and Week view modes', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const PlannerView(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Blocks'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);

      // Tap 'Blocks' to enter time blocking timeline
      await tester.tap(find.text('Blocks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+ Deep Work (2h)'), findsOneWidget);

      // Tap 'Week'
      await tester.tap(find.text('Week'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No events'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
