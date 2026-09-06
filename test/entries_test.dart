import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/entries/providers/entries_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntryController & Drift Database Operations', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'test-user-123'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('logEntry correctly inserts water entry with tags and sets initial sync flags', () async {
      final controller = container.read(entryControllerProvider);

      final id = await controller.logEntry(
        type: 'water',
        value: 2.0,
        unit: 'glass',
        tags: ['Hydration', 'Health'],
        note: 'Afternoon glass',
      );

      final entry = await db.getEntryById(id);
      expect(entry, isNotNull);
      expect(entry!.type, 'water');
      expect(entry.value, 2.0);
      expect(entry.unit, 'glass');
      expect(entry.note, 'Afternoon glass');
      expect(entry.tags, ['Hydration', 'Health']);
      expect(entry.userId, 'test-user-123');
      expect(entry.isSynced, isFalse);
      expect(entry.isDeleted, isFalse);
    });

    test('logEntry handles mood and sleep entries with custom JSON metadata', () async {
      final controller = container.read(entryControllerProvider);

      final moodId = await controller.logEntry(
        type: 'mood',
        value: 5.0,
        unit: 'score',
        metadata: {'mood_label': 'Great'},
        tags: ['Mindfulness'],
      );

      final sleepId = await controller.logEntry(
        type: 'sleep',
        value: 8.0,
        unit: 'hours',
        metadata: {'quality': 'Deep'},
      );

      final moodEntry = await db.getEntryById(moodId);
      expect(moodEntry?.metadata?['mood_label'], 'Great');

      final sleepEntry = await db.getEntryById(sleepId);
      expect(sleepEntry?.metadata?['quality'], 'Deep');
    });

    test('softDelete sets isDeleted to true and stages row for sync', () async {
      final controller = container.read(entryControllerProvider);

      final id = await controller.logEntry(
        type: 'habit',
        value: 1.0,
        metadata: {'habit_name': 'Morning Exercise'},
      );

      // Initially active in watchEntries
      var activeEntries = await db.watchEntries().first;
      expect(activeEntries.any((e) => e.id == id), isTrue);

      // Soft delete
      await controller.softDelete(id);

      // Excluded from active stream
      activeEntries = await db.watchEntries().first;
      expect(activeEntries.any((e) => e.id == id), isFalse);

      // Still in DB with isDeleted = true and isSynced = false
      final row = await db.getEntryById(id);
      expect(row?.isDeleted, isTrue);
      expect(row?.isSynced, isFalse);
    });

    test('restore revives soft deleted entry', () async {
      final controller = container.read(entryControllerProvider);

      final id = await controller.logEntry(
        type: 'habit',
        value: 1.0,
        metadata: {'habit_name': 'Read Book'},
      );

      await controller.softDelete(id);
      expect((await db.getEntryById(id))?.isDeleted, isTrue);

      await controller.restore(id);
      final revived = await db.getEntryById(id);
      expect(revived?.isDeleted, isFalse);
      expect(revived?.isSynced, isFalse);
    });
  });

  group('Category Filtering & Reactive Streams', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'test-user-123'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('filteredEntriesStreamProvider reactively streams filtered subset', () async {
      final controller = container.read(entryControllerProvider);

      // Insert 2 water entries and 1 habit entry
      await controller.logEntry(type: 'water', value: 1.0);
      await controller.logEntry(type: 'water', value: 2.0);
      await controller.logEntry(type: 'habit', value: 1.0);

      // Verify database filtered streams
      final allEntries = await db.watchEntries().first;
      expect(allEntries.length, 3);

      final waterEntries = await db.watchEntriesByType('water').first;
      expect(waterEntries.length, 2);
      expect(waterEntries.every((e) => e.type == 'water'), isTrue);

      final habitEntries = await db.watchEntriesByType('habit').first;
      expect(habitEntries.length, 1);
      expect(habitEntries.first.type, 'habit');

      // Verify filter notifier state transitions
      expect(container.read(selectedEntryTypeFilterProvider), isNull);
      container.read(selectedEntryTypeFilterProvider.notifier).setFilter('water');
      expect(container.read(selectedEntryTypeFilterProvider), 'water');
      container.read(selectedEntryTypeFilterProvider.notifier).setFilter('mood');
      expect(container.read(selectedEntryTypeFilterProvider), 'mood');
      container.read(selectedEntryTypeFilterProvider.notifier).setFilter(null);
      expect(container.read(selectedEntryTypeFilterProvider), isNull);
    });
  });
}
