import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';

void main() {
  late AppDatabase db;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift Local Database - Entries Table', () {
    test('Can insert and retrieve an entry with JSON-encoded tags and metadata', () async {
      final id = uuid.v4();
      final userId = uuid.v4();
      final now = DateTime.now();

      final companion = EntriesCompanion.insert(
        id: id,
        userId: userId,
        type: 'water',
        value: 8.0,
        unit: const Value('glasses'),
        note: const Value('Drank 8 glasses of water today'),
        tags: const Value(['Health', 'Hydration']),
        metadata: const Value({'source': 'manual_quick_add', 'temp': 'cold'}),
        occurredAt: now,
      );

      await db.upsertEntry(companion);

      final entries = await db.watchEntries().first;
      expect(entries.length, 1);
      final entry = entries.first;
      expect(entry.id, id);
      expect(entry.userId, userId);
      expect(entry.type, 'water');
      expect(entry.value, 8.0);
      expect(entry.unit, 'glasses');
      expect(entry.tags, ['Health', 'Hydration']);
      expect(entry.metadata?['source'], 'manual_quick_add');
      expect(entry.isSynced, false);
      expect(entry.isDeleted, false);
    });

    test('Filtering entries by type works reactively', () async {
      final now = DateTime.now();

      await db.upsertEntry(EntriesCompanion.insert(
        id: uuid.v4(),
        userId: 'user_1',
        type: 'water',
        value: 4.0,
        occurredAt: now,
      ));

      await db.upsertEntry(EntriesCompanion.insert(
        id: uuid.v4(),
        userId: 'user_1',
        type: 'mood',
        value: 5.0,
        occurredAt: now,
      ));

      final waterEntries = await db.watchEntriesByType('water').first;
      final moodEntries = await db.watchEntriesByType('mood').first;

      expect(waterEntries.length, 1);
      expect(waterEntries.first.type, 'water');
      expect(moodEntries.length, 1);
      expect(moodEntries.first.type, 'mood');
    });

    test('Soft delete excludes entry from active streams and stages for sync', () async {
      final id = uuid.v4();
      final now = DateTime.now();

      await db.upsertEntry(EntriesCompanion.insert(
        id: id,
        userId: 'user_1',
        type: 'sleep',
        value: 7.5,
        occurredAt: now,
      ));

      var active = await db.watchEntries().first;
      expect(active.length, 1);

      await db.softDeleteEntry(id);

      active = await db.watchEntries().first;
      expect(active, isEmpty);

      final unsynced = await db.getUnsyncedEntries();
      expect(unsynced.length, 1);
      expect(unsynced.first.isDeleted, true);
      expect(unsynced.first.isSynced, false);
    });

    test('markAsSynced updates sync status for background worker', () async {
      final id = uuid.v4();
      final now = DateTime.now();

      await db.upsertEntry(EntriesCompanion.insert(
        id: id,
        userId: 'user_1',
        type: 'journal',
        value: 1.0,
        note: const Value('Reflecting on day 1'),
        occurredAt: now,
      ));

      var unsynced = await db.getUnsyncedEntries();
      expect(unsynced.length, 1);

      await db.markAsSynced(id);

      unsynced = await db.getUnsyncedEntries();
      expect(unsynced, isEmpty);
    });
  });
}
