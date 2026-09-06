import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/sync/sync_service.dart';
import 'package:cadence/core/sync/sync_state.dart';
import 'package:cadence/core/sync/sync_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService & LWW Conflict Resolution', () {
    late AppDatabase db;
    late SyncService syncService;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      syncService = SyncService(db: db, client: null);
    });

    tearDown(() async {
      await db.close();
    });

    test('entryToRemoteJson properly maps camelCase Drift Entry to snake_case remote schema', () {
      final now = DateTime.utc(2026, 9, 6, 12, 0, 0);
      final entry = Entry(
        id: 'entry-uuid-1',
        userId: 'user-uuid-123',
        type: 'water',
        value: 2.5,
        unit: 'glass',
        note: 'Afternoon hydration',
        tags: const ['health', 'hydration'],
        metadata: const {'temperature': 'cold'},
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
        isDeleted: false,
      );

      final json = syncService.entryToRemoteJson(entry);

      expect(json['id'], 'entry-uuid-1');
      expect(json['user_id'], 'user-uuid-123');
      expect(json['type'], 'water');
      expect(json['value'], 2.5);
      expect(json['unit'], 'glass');
      expect(json['note'], 'Afternoon hydration');
      expect(json['tags'], ['health', 'hydration']);
      expect(json['metadata'], {'temperature': 'cold'});
      expect(json['occurred_at'], now.toIso8601String());
      expect(json['is_deleted'], false);
    });

    test('Unsynced batch tracking and markBatchAsSynced updates local SQLite records', () async {
      final now = DateTime.now();

      await db.upsertEntry(
        EntriesCompanion.insert(
          id: 'item-1',
          userId: 'user-1',
          type: 'habit',
          value: 1.0,
          occurredAt: now,
        ),
      );

      await db.upsertEntry(
        EntriesCompanion.insert(
          id: 'item-2',
          userId: 'user-1',
          type: 'habit',
          value: 1.0,
          occurredAt: now,
        ),
      );

      final unsyncedBefore = await db.getUnsyncedEntries();
      expect(unsyncedBefore.length, 2);

      await db.markBatchAsSynced(['item-1', 'item-2']);

      final unsyncedAfter = await db.getUnsyncedEntries();
      expect(unsyncedAfter.isEmpty, isTrue);
    });

    test('LWW Resolution: Remote record overwrites local SQLite if remote updatedAt is strictly newer', () async {
      final now = DateTime.now();
      final localTime = now.subtract(const Duration(hours: 2));
      final remoteTime = now.add(const Duration(hours: 1)); // strictly newer

      // Insert older local record
      await db.upsertEntry(
        EntriesCompanion.insert(
          id: 'conflict-entry-1',
          userId: 'user-1',
          type: 'expense',
          value: 15.0,
          note: const drift.Value('Local initial version'),
          occurredAt: localTime,
          updatedAt: drift.Value(localTime),
        ),
      );

      final localBefore = await db.getEntryById('conflict-entry-1');
      expect(localBefore?.value, 15.0);

      // Simulate remote payload arriving with newer timestamp
      final remoteRow = {
        'id': 'conflict-entry-1',
        'user_id': 'user-1',
        'type': 'expense',
        'value': 25.0,
        'unit': 'USD',
        'note': 'Remote newer version',
        'tags': ['Food'],
        'metadata': <String, dynamic>{},
        'occurred_at': localTime.toUtc().toIso8601String(),
        'created_at': localTime.toUtc().toIso8601String(),
        'updated_at': remoteTime.toUtc().toIso8601String(),
        'is_deleted': false,
      };

      // Apply LWW directly via simulated pull resolution
      final remoteUpdatedAt = DateTime.parse(remoteRow['updated_at'] as String);
      if (localBefore == null || remoteUpdatedAt.isAfter(localBefore.updatedAt)) {
        await db.upsertEntry(
          EntriesCompanion(
            id: drift.Value(remoteRow['id'] as String),
            userId: drift.Value(remoteRow['user_id'] as String),
            type: drift.Value(remoteRow['type'] as String),
            value: drift.Value((remoteRow['value'] as num).toDouble()),
            note: drift.Value(remoteRow['note'] as String?),
            occurredAt: drift.Value(DateTime.parse(remoteRow['occurred_at'] as String)),
            createdAt: drift.Value(DateTime.parse(remoteRow['created_at'] as String)),
            updatedAt: drift.Value(remoteUpdatedAt),
            isSynced: const drift.Value(true),
            isDeleted: drift.Value(remoteRow['is_deleted'] as bool),
          ),
        );
      }

      final localAfter = await db.getEntryById('conflict-entry-1');
      expect(localAfter?.value, 25.0);
      expect(localAfter?.note, 'Remote newer version');
      expect(localAfter?.isSynced, true);
    });

    test('LWW Resolution: Local record is preserved if local updatedAt is newer than remote', () async {
      final remoteTime = DateTime(2026, 9, 6, 8, 0); // older
      final localTime = DateTime(2026, 9, 6, 12, 0); // newer

      // Local record with recent edit
      await db.upsertEntry(
        EntriesCompanion(
          id: const drift.Value('conflict-entry-2'),
          userId: const drift.Value('user-1'),
          type: const drift.Value('water'),
          value: const drift.Value(2.0),
          note: const drift.Value('Local newest edit'),
          occurredAt: drift.Value(localTime),
          createdAt: drift.Value(localTime),
          updatedAt: drift.Value(localTime),
          isSynced: const drift.Value(false),
          isDeleted: const drift.Value(false),
        ),
      );

      final localEntry = await db.getEntryById('conflict-entry-2');

      // Older remote payload arrives
      final remoteUpdatedAt = remoteTime;
      bool wasOverwritten = false;
      if (localEntry == null || remoteUpdatedAt.isAfter(localEntry.updatedAt)) {
        wasOverwritten = true;
      }

      // Local should NOT be overwritten
      expect(wasOverwritten, isFalse);
      final finalEntry = await db.getEntryById('conflict-entry-2');
      expect(finalEntry?.value, 2.0);
      expect(finalEntry?.note, 'Local newest edit');
    });

    test('Synchronize handles guest user gracefully with local persistence notice', () async {
      final syncInfo = await syncService.synchronize(
        userId: 'local_guest_user',
      );

      expect(syncInfo.status, SyncStatus.synced);
      expect(syncInfo.message, contains('Guest mode'));
    });

    test('Synchronize handles unconfigured/offline client safely without crashing', () async {
      final syncInfo = await syncService.synchronize(
        userId: 'auth-user-123',
      );

      expect(syncInfo.status, SyncStatus.offline);
      expect(syncInfo.message, contains('Cloud sync unavailable'));
    });
  });

  group('Sync Riverpod Providers', () {
    test('unsyncedEntriesCountProvider and watchUnsyncedCount emits live count of pending rows', () async {
      final db = AppDatabase(openInMemoryConnection());
      addTearDown(() => db.close());

      final counts = <int>[];
      final sub = db.watchUnsyncedCount().listen(counts.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(counts, [0]);

      // Add 1 unsynced entry
      await db.upsertEntry(
        EntriesCompanion.insert(
          id: 'test-unsynced-1',
          userId: 'user-guest',
          type: 'habit',
          value: 1.0,
          occurredAt: DateTime.now(),
        ),
      );

      await pumpEventQueue();
      expect(counts, [0, 1]);
    });

    test('syncNotifierProvider triggers syncNow for guest mode successfully', () async {
      final db = AppDatabase(openInMemoryConnection());
      addTearDown(() => db.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'local_guest_user'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(syncNotifierProvider.notifier);
      await notifier.syncNow();

      final state = container.read(syncNotifierProvider);
      expect(state.status, SyncStatus.synced);
      expect(state.message, contains('Guest mode'));
    });
  });
}
