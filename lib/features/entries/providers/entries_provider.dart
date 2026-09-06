import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';

/// Filter notifier managing active category filter state.
class EntryTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? filter) => state = filter;
}

/// Currently selected entry type filter. `null` represents All categories.
final selectedEntryTypeFilterProvider =
    NotifierProvider<EntryTypeFilterNotifier, String?>(
  () => EntryTypeFilterNotifier(),
);

/// Reactive stream provider for entries based on active category filter.
final filteredEntriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(selectedEntryTypeFilterProvider);

  if (filter == null || filter.isEmpty) {
    return db.watchEntries();
  }
  return db.watchEntriesByType(filter);
});

/// Domain controller managing entry creation, soft deletion, and undo restoration.
class EntryController {
  final AppDatabase _db;
  final Ref _ref;

  EntryController(this._db, this._ref);

  /// Create and persist a new polymorphic entry.
  Future<String> logEntry({
    required String type,
    required double value,
    String? unit,
    String? note,
    List<String> tags = const [],
    Map<String, dynamic> metadata = const {},
    DateTime? occurredAt,
  }) async {
    const uuid = Uuid();
    final entryId = uuid.v4();
    final userId = _ref.read(activeUserIdProvider);
    final now = DateTime.now();

    await _db.upsertEntry(
      EntriesCompanion.insert(
        id: entryId,
        userId: userId,
        type: type,
        value: value,
        unit: drift.Value(unit),
        note: drift.Value(note),
        tags: drift.Value(tags),
        metadata: drift.Value(metadata),
        occurredAt: occurredAt ?? now,
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        isSynced: const drift.Value(false),
        isDeleted: const drift.Value(false),
      ),
    );

    return entryId;
  }

  /// Soft deletes an entry so the deletion propagates across offline devices.
  Future<void> softDelete(String id) async {
    await _db.softDeleteEntry(id);
  }

  /// Restores a soft-deleted entry (e.g. from an undo snackbar).
  Future<void> restore(String id) async {
    final existing = await _db.getEntryById(id);
    if (existing != null) {
      await _db.upsertEntry(
        EntriesCompanion(
          id: drift.Value(existing.id),
          userId: drift.Value(existing.userId),
          type: drift.Value(existing.type),
          value: drift.Value(existing.value),
          unit: drift.Value(existing.unit),
          note: drift.Value(existing.note),
          tags: drift.Value(existing.tags),
          metadata: drift.Value(existing.metadata),
          occurredAt: drift.Value(existing.occurredAt),
          createdAt: drift.Value(existing.createdAt),
          updatedAt: drift.Value(DateTime.now()),
          isSynced: const drift.Value(false),
          isDeleted: const drift.Value(false),
        ),
      );
    }
  }
}

/// Provider exposing the EntryController.
final entryControllerProvider = Provider<EntryController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EntryController(db, ref);
});
