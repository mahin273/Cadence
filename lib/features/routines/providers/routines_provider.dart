import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../models/routine_models.dart';

/// Provider managing the selected calendar date for routine completion viewing.
class SelectedRoutineDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void selectDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void resetToToday() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, now.day);
  }
}

final selectedRoutineDateProvider =
    NotifierProvider<SelectedRoutineDateNotifier, DateTime>(
  SelectedRoutineDateNotifier.new,
);

/// Watch all active routines with their checklist items and today's completion state.
final routinesWithItemsStreamProvider =
    StreamProvider<List<RoutineWithItems>>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final selectedDate = ref.watch(selectedRoutineDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  Future<List<RoutineWithItems>> loadRoutines() async {
    final routines = await (db.select(db.routines)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.sortOrder)]))
        .get();
    final completions = await db.getCompletionsForDate(dateStr);
    final completedItemIds = completions.map((c) => c.itemId).toSet();

    final result = <RoutineWithItems>[];
    for (final routine in routines) {
      final items = await db.getItemsForRoutine(routine.id);
      result.add(
        RoutineWithItems(
          routine: routine,
          items: items,
          completedItemIds: completedItemIds,
        ),
      );
    }
    return result;
  }

  yield await loadRoutines();

  final updateStream = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.routines,
      db.routineItems,
      db.routineCompletions,
    ]),
  );

  await for (final _ in updateStream) {
    yield await loadRoutines();
  }
});

/// Controller providing mutating user actions for routines and checklist steps.
class RoutinesController {
  final AppDatabase _db;
  final Ref _ref;

  RoutinesController(this._db, this._ref);

  /// Toggle completion state of a specific checklist item for a given date.
  Future<bool> toggleItem(
    String routineId,
    String itemId, [
    DateTime? date,
  ]) async {
    final DateTime targetDate = date ?? _ref.read(selectedRoutineDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    return await _db.toggleRoutineItemCompletion(routineId, itemId, dateStr);
  }

  /// Reorder items within a routine.
  Future<void> reorderItems(
    String routineId,
    List<String> itemIdsInOrder,
  ) async {
    await _db.reorderRoutineItems(itemIdsInOrder);
  }

  /// Create a new routine with initial checklist items.
  Future<String> createRoutine({
    required String title,
    String? description,
    String timeOfDay = 'morning',
    String iconName = 'wb_sunny_rounded',
    int colorValue = 0xFF2196F3,
    required List<String> itemTitles,
  }) async {
    final routineId = const Uuid().v4();
    final now = DateTime.now();

    final routineCompanion = RoutinesCompanion.insert(
      id: routineId,
      title: title,
      description: drift.Value(description),
      timeOfDay: drift.Value(timeOfDay),
      iconName: drift.Value(iconName),
      colorValue: drift.Value(colorValue),
      sortOrder: const drift.Value(0),
      isActive: const drift.Value(true),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    );

    final itemCompanions = <RoutineItemsCompanion>[];
    for (int i = 0; i < itemTitles.length; i++) {
      itemCompanions.add(
        RoutineItemsCompanion.insert(
          id: const Uuid().v4(),
          routineId: routineId,
          title: itemTitles[i],
          durationMinutes: const drift.Value(5),
          sortOrder: drift.Value(i),
          isRequired: const drift.Value(true),
          createdAt: drift.Value(now),
        ),
      );
    }

    await _db.createRoutineWithItems(routineCompanion, itemCompanions);
    return routineId;
  }

  /// Add a single checklist item to an existing routine.
  Future<void> addChecklistItem(
    String routineId,
    String title, {
    int durationMinutes = 5,
  }) async {
    final existingItems = await _db.getItemsForRoutine(routineId);
    final nextSortOrder = existingItems.length;

    await _db.createRoutineItem(
      RoutineItemsCompanion.insert(
        id: const Uuid().v4(),
        routineId: routineId,
        title: title,
        durationMinutes: drift.Value(durationMinutes),
        sortOrder: drift.Value(nextSortOrder),
        isRequired: const drift.Value(true),
        createdAt: drift.Value(DateTime.now()),
      ),
    );
  }

  /// Delete an entire routine and cascade delete its checklist steps and completions.
  Future<void> deleteRoutine(String routineId) async {
    await _db.deleteRoutine(routineId);
  }

  /// Delete a single checklist step.
  Future<void> deleteChecklistItem(String itemId) async {
    await _db.deleteRoutineItem(itemId);
  }
}

/// Provider exposing RoutinesController methods.
final routinesControllerProvider = Provider<RoutinesController>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RoutinesController(db, ref);
});
