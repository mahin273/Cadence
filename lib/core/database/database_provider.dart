import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Global provider for the singleton local SQLite Drift database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Reactive stream provider for all active entries.
final entriesStreamProvider = StreamProvider<List<Entry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchEntries();
});

/// Reactive stream provider for entries filtered by type.
final entriesByTypeProvider = StreamProvider.family<List<Entry>, String>((ref, type) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchEntriesByType(type);
});

/// Reactive stream provider for entries filtered by day.
final entriesForDayProvider = StreamProvider.family<List<Entry>, DateTime>((ref, day) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchEntriesForDay(day);
});
