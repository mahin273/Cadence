import 'package:drift/drift.dart';
import 'converters/json_converters.dart';
import 'tables/entries_table.dart';
import 'connection/native_connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  // -------------------------------------------------------------
  // Reactive Streams (for UI consumption via Riverpod)
  // -------------------------------------------------------------

  /// Watch active (non-deleted) entries sorted chronologically.
  Stream<List<Entry>> watchEntries() {
    return (select(entries)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Watch active entries filtered by type (e.g. 'water', 'habit', 'mood').
  Stream<List<Entry>> watchEntriesByType(String type) {
    return (select(entries)
          ..where((tbl) => tbl.type.equals(type) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  /// Watch entries for a specific calendar day.
  Stream<List<Entry>> watchEntriesForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (select(entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerThanValue(endOfDay) &
              tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }

  // -------------------------------------------------------------
  // Sync Operations (for offline-first background engine)
  // -------------------------------------------------------------

  /// Retrieve all entries that have not yet been synced to Supabase.
  Future<List<Entry>> getUnsyncedEntries() {
    return (select(entries)..where((tbl) => tbl.isSynced.equals(false))).get();
  }

  /// Watch count of unsynced entries for UI badges and indicators.
  Stream<int> watchUnsyncedCount() {
    final count = entries.id.count();
    final query = selectOnly(entries)
      ..addColumns([count])
      ..where(entries.isSynced.equals(false));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Retrieve single entry by UUID for conflict resolution.
  Future<Entry?> getEntryById(String id) {
    return (select(entries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Mark an entry as successfully synced with remote Supabase DB.
  Future<int> markAsSynced(String id) {
    return (update(entries)..where((tbl) => tbl.id.equals(id))).write(
      const EntriesCompanion(
        isSynced: Value(true),
      ),
    );
  }

  /// Mark a batch of entries as successfully synced in a single query.
  Future<int> markBatchAsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(entries)..where((tbl) => tbl.id.isIn(ids))).write(
      const EntriesCompanion(
        isSynced: Value(true),
      ),
    );
  }

  // -------------------------------------------------------------
  // Mutation Operations
  // -------------------------------------------------------------

  /// Insert or update an entry.
  Future<int> upsertEntry(EntriesCompanion entry) {
    return into(entries).insertOnConflictUpdate(entry);
  }

  /// Soft delete an entry so deletion can be synced to remote server.
  Future<int> softDeleteEntry(String id) {
    return (update(entries)..where((tbl) => tbl.id.equals(id))).write(
      EntriesCompanion(
        isDeleted: const Value(true),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Hard delete an entry (used for local purges).
  Future<int> hardDeleteEntry(String id) {
    return (delete(entries)..where((tbl) => tbl.id.equals(id))).go();
  }
}
