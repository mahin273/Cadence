import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/routines/providers/routines_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoutinesController & Database Operations', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-routines-user';

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

    test('createRoutine creates routine template and items with sequential sort order', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Morning Launchpad',
        description: 'Morning priming sequence',
        timeOfDay: 'morning',
        colorValue: 0xFFFFB74D,
        itemTitles: [
          'Hydrate 500ml',
          'Sunlight 10 mins',
          'Mobility stretches',
        ],
      );

      final routines = await db.watchActiveRoutines().first;
      expect(routines.length, 1);
      final routine = routines.first;
      expect(routine.id, routineId);
      expect(routine.title, 'Morning Launchpad');
      expect(routine.timeOfDay, 'morning');
      expect(routine.colorValue, 0xFFFFB74D);

      final items = await db.watchItemsForRoutine(routineId).first;
      expect(items.length, 3);
      expect(items[0].title, 'Hydrate 500ml');
      expect(items[0].sortOrder, 0);
      expect(items[1].title, 'Sunlight 10 mins');
      expect(items[1].sortOrder, 1);
      expect(items[2].title, 'Mobility stretches');
      expect(items[2].sortOrder, 2);
    });

    test('toggleRoutineItemCompletion inserts on first tap and deletes on second tap', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Work Prep',
        description: 'Start of workday',
        timeOfDay: 'afternoon',
        colorValue: 0xFF2196F3,
        itemTitles: ['Clear desk', 'Check calendar'],
      );

      final items = await db.watchItemsForRoutine(routineId).first;
      final firstItemId = items.first.id;
      final targetDate = DateTime(2026, 9, 8);
      const dateStr = '2026-09-08';

      // Initially no completions
      var completions = await db.watchCompletionsForDate(dateStr).first;
      expect(completions, isEmpty);

      // Toggle ON
      await controller.toggleItem(routineId, firstItemId, targetDate);
      completions = await db.watchCompletionsForDate(dateStr).first;
      expect(completions.length, 1);
      expect(completions.first.itemId, firstItemId);
      expect(completions.first.completedDate, dateStr);

      // Toggle OFF
      await controller.toggleItem(routineId, firstItemId, targetDate);
      completions = await db.watchCompletionsForDate(dateStr).first;
      expect(completions, isEmpty);
    });

    test('automatic daily rollover: completions for today do not affect tomorrow', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Daily Hygiene',
        description: 'Daily consistency',
        timeOfDay: 'anytime',
        colorValue: 0xFF4CAF50,
        itemTitles: ['Floss & brush teeth'],
      );

      final items = await db.watchItemsForRoutine(routineId).first;
      final itemId = items.first.id;

      final date1 = DateTime(2026, 9, 8);
      const date1Str = '2026-09-08';
      const date2Str = '2026-09-09';

      // Complete on date 1
      await controller.toggleItem(routineId, itemId, date1);

      // Verify date 1 has completion
      final completionsDay1 = await db.watchCompletionsForDate(date1Str).first;
      expect(completionsDay1.length, 1);

      // Querying date 2 has ZERO completions (automatic rollover!)
      final completionsDay2 = await db.watchCompletionsForDate(date2Str).first;
      expect(completionsDay2, isEmpty);
    });

    test('reorderRoutineItems updates sort orders sequentially in a transaction', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Workout Order',
        description: 'Testing reorder',
        timeOfDay: 'afternoon',
        colorValue: 0xFFE91E63,
        itemTitles: ['Item A', 'Item B', 'Item C'],
      );

      final items = await db.watchItemsForRoutine(routineId).first;
      final itemA = items[0];
      final itemB = items[1];
      final itemC = items[2];

      // Reorder to C, A, B
      await controller.reorderItems(routineId, [itemC.id, itemA.id, itemB.id]);

      final reordered = await db.watchItemsForRoutine(routineId).first;
      expect(reordered[0].id, itemC.id);
      expect(reordered[0].sortOrder, 0);
      expect(reordered[1].id, itemA.id);
      expect(reordered[1].sortOrder, 1);
      expect(reordered[2].id, itemB.id);
      expect(reordered[2].sortOrder, 2);
    });

    test('deleteRoutine cascades to remove child items and completions', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Temporary Routine',
        description: 'To be deleted',
        timeOfDay: 'evening',
        colorValue: 0xFF9E9E9E,
        itemTitles: ['Step 1', 'Step 2'],
      );

      final items = await db.watchItemsForRoutine(routineId).first;
      expect(items.length, 2);

      await controller.toggleItem(routineId, items.first.id, DateTime(2026, 9, 8));
      var completions = await db.watchCompletionsForDate('2026-09-08').first;
      expect(completions.length, 1);

      // Delete routine
      await controller.deleteRoutine(routineId);

      // Verify routine is deleted
      final routines = await db.watchActiveRoutines().first;
      expect(routines, isEmpty);

      // Verify items are deleted
      final remainingItems = await db.watchItemsForRoutine(routineId).first;
      expect(remainingItems, isEmpty);

      // Verify completions are deleted
      completions = await db.watchCompletionsForDate('2026-09-08').first;
      expect(completions, isEmpty);
    });

    test('deleteChecklistItem removes individual item and its completions', () async {
      final controller = container.read(routinesControllerProvider);
      final routineId = await controller.createRoutine(
        title: 'Multi-step',
        description: 'Test delete item',
        timeOfDay: 'morning',
        colorValue: 0xFF009688,
        itemTitles: ['Task 1', 'Task 2'],
      );

      final items = await db.watchItemsForRoutine(routineId).first;
      final task1 = items.first;

      await controller.toggleItem(routineId, task1.id, DateTime(2026, 9, 8));
      var completions = await db.watchCompletionsForDate('2026-09-08').first;
      expect(completions.length, 1);

      await controller.deleteChecklistItem(task1.id);

      final remainingItems = await db.watchItemsForRoutine(routineId).first;
      expect(remainingItems.length, 1);
      expect(remainingItems.first.title, 'Task 2');

      completions = await db.watchCompletionsForDate('2026-09-08').first;
      expect(completions, isEmpty);
    });
  });
}
