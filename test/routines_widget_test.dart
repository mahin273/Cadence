import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/routines/models/routine_models.dart';
import 'package:cadence/features/routines/presentation/routines_view.dart';
import 'package:cadence/features/routines/providers/routines_provider.dart';
import 'package:cadence/features/routines/widgets/routine_card.dart';
import 'package:cadence/features/routines/widgets/routine_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-routines-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Routines UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('RoutineItemTile renders title and responds to checkbox tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'test-routines-user'),
        ],
      );
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Morning Flow',
        itemTitles: ['Drink 500ml water'],
      );
      final items = await db.getItemsForRoutine(routineId);
      final testItem = items.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: RoutineItemTile(
                routineId: routineId,
                item: testItem,
                isCompleted: false,
                index: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Drink 500ml water'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap Checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final completions = await db.getCompletionsForDate(todayStr);
      expect(completions.length, 1);
      expect(completions.first.itemId, testItem.id);

      container.dispose();
    });

    testWidgets('RoutineCard displays title, progress indicator, and items', (tester) async {
      final routine = Routine(
        id: 'routine-1',
        title: 'Morning Routine',
        description: 'Wake up fresh',
        timeOfDay: 'morning',
        iconName: 'wb_sunny_rounded',
        colorValue: 0xFFFFB74D,
        sortOrder: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final items = [
        RoutineItem(
          id: 'item-1',
          routineId: 'routine-1',
          title: 'Sunlight',
          durationMinutes: 10,
          sortOrder: 0,
          isRequired: true,
          createdAt: DateTime.now(),
        ),
        RoutineItem(
          id: 'item-2',
          routineId: 'routine-1',
          title: 'Cold shower',
          durationMinutes: 5,
          sortOrder: 1,
          isRequired: true,
          createdAt: DateTime.now(),
        ),
      ];

      final routineWithItems = RoutineWithItems(
        routine: routine,
        items: items,
        completedItemIds: {'item-1'},
      );

      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: RoutineCard(
            routineWithItems: routineWithItems,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Morning Routine'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Sunlight'), findsOneWidget);
      expect(find.text('Cold shower'), findsOneWidget);
    });

    testWidgets('RoutinesView displays empty state with quick starter templates', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const RoutinesView(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Daily Routines'), findsOneWidget);
      expect(find.text('No Daily Routines Yet'), findsOneWidget);
      expect(find.text('+ Morning Launchpad'), findsOneWidget);
      expect(find.text('+ Evening Shutdown'), findsOneWidget);

      // Tap + Morning Launchpad starter button
      await tester.tap(find.text('+ Morning Launchpad'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Now routine card should appear
      expect(find.text('Morning Launchpad'), findsOneWidget);
      expect(find.text('Drink 500ml water with electrolytes'), findsOneWidget);
    });
  });
}
