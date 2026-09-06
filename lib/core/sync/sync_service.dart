import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import 'sync_state.dart';

/// Bidirectional synchronization engine between local Drift SQLite and Supabase PostgreSQL.
class SyncService {
  final AppDatabase db;
  final SupabaseClient? client;

  SyncService({
    required this.db,
    this.client,
  });

  /// Map local Drift Entry model into Supabase JSON payload.
  Map<String, dynamic> entryToRemoteJson(Entry entry) {
    return {
      'id': entry.id,
      'user_id': entry.userId,
      'type': entry.type,
      'value': entry.value,
      'unit': entry.unit,
      'note': entry.note,
      'tags': entry.tags,
      'metadata': entry.metadata,
      'occurred_at': entry.occurredAt.toUtc().toIso8601String(),
      'created_at': entry.createdAt.toUtc().toIso8601String(),
      'updated_at': entry.updatedAt.toUtc().toIso8601String(),
      'is_deleted': entry.isDeleted,
    };
  }

  /// Push locally modified or created entries that have `is_synced == false`.
  Future<int> pushUnsyncedEntries({required String userId}) async {
    if (client == null) return 0;

    final unsynced = await db.getUnsyncedEntries();
    final toPush = unsynced.where((e) => e.userId == userId).toList();
    if (toPush.isEmpty) return 0;

    final payloads = toPush.map(entryToRemoteJson).toList();
    await client!.from('entries').upsert(payloads);

    final pushedIds = toPush.map((e) => e.id).toList();
    await db.markBatchAsSynced(pushedIds);

    return toPush.length;
  }

  /// Pull remote updates since [since] cursor, applying Last-Write-Wins (LWW) conflict resolution.
  Future<int> pullRemoteEntries({
    required String userId,
    DateTime? since,
  }) async {
    if (client == null) return 0;

    var query = client!.from('entries').select().eq('user_id', userId);
    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }

    final response = await query;
    final List<dynamic> rows = response as List<dynamic>;
    int pulledCount = 0;

    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final id = row['id'] as String;
      final remoteUpdatedAt = DateTime.parse(row['updated_at'] as String);
      final localEntry = await db.getEntryById(id);

      // Last-Write-Wins: Remote wins if local record does not exist or remote is strictly newer
      if (localEntry == null || remoteUpdatedAt.isAfter(localEntry.updatedAt)) {
        final tagsRaw = row['tags'];
        List<String> tags = [];
        if (tagsRaw is List) {
          tags = tagsRaw.map((e) => e.toString()).toList();
        }

        final metadataRaw = row['metadata'];
        Map<String, dynamic> metadata = {};
        if (metadataRaw is Map) {
          metadata = Map<String, dynamic>.from(metadataRaw);
        }

        await db.upsertEntry(
          EntriesCompanion(
            id: Value(id),
            userId: Value(row['user_id'] as String),
            type: Value(row['type'] as String),
            value: Value((row['value'] as num?)?.toDouble() ?? 0.0),
            unit: Value(row['unit'] as String?),
            note: Value(row['note'] as String?),
            tags: Value(tags),
            metadata: Value(metadata),
            occurredAt: Value(DateTime.parse(row['occurred_at'] as String).toLocal()),
            createdAt: Value(DateTime.parse(row['created_at'] as String).toLocal()),
            updatedAt: Value(remoteUpdatedAt.toLocal()),
            isSynced: const Value(true),
            isDeleted: Value(row['is_deleted'] as bool? ?? false),
          ),
        );
        pulledCount++;
      }
    }

    return pulledCount;
  }

  /// Execute a complete bidirectional sync cycle (Push then Pull).
  Future<SyncInfo> synchronize({
    required String userId,
    DateTime? lastSyncedAt,
  }) async {
    if (userId == 'local_guest_user') {
      return SyncInfo(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        message: 'Guest mode: entries preserved locally in SQLite',
      );
    }

    if (client == null) {
      return SyncInfo(
        status: SyncStatus.offline,
        lastSyncedAt: lastSyncedAt,
        message: 'Cloud sync unavailable (offline / unconfigured)',
      );
    }

    try {
      final pushed = await pushUnsyncedEntries(userId: userId);
      final pulled = await pullRemoteEntries(userId: userId, since: lastSyncedAt);

      return SyncInfo(
        status: SyncStatus.synced,
        lastSyncedAt: DateTime.now(),
        pushedCount: pushed,
        pulledCount: pulled,
        message: 'Synced: $pushed pushed, $pulled pulled',
      );
    } catch (e) {
      return SyncInfo(
        status: SyncStatus.error,
        lastSyncedAt: lastSyncedAt,
        message: 'Sync error: $e',
      );
    }
  }
}
