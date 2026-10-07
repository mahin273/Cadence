import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../models/habit_streak_models.dart';
import '../services/habit_streak_service.dart';

/// Provider for the habit streak calculation engine.
final habitStreakServiceProvider = Provider<HabitStreakService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitStreakService(db);
});

/// Reactive stream provider for 365-day streak statistics and activity heatmap distribution.
final habitStreakStatsProvider = StreamProvider<StreakStats>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(habitStreakServiceProvider);

  // Initial calculation
  yield await service.calculateConsistencyStats(days: 365);

  // Watch for any changes in routine completions, focus sessions, routes, or entries
  final updates = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.routineCompletions,
      db.studySessions,
      db.routes,
      db.entries,
    ]),
  );

  await for (final _ in updates) {
    yield await service.calculateConsistencyStats(days: 365);
  }
});
