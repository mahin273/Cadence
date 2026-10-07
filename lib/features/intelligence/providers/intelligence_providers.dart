import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../models/life_intelligence_models.dart';
import '../services/intelligence_engine_service.dart';

/// Provider for the intelligence engine service.
final intelligenceServiceProvider = Provider<IntelligenceEngineService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return IntelligenceEngineService(db);
});

/// State notifier for the active intelligence time window (days).
class IntelligenceWindowDaysNotifier extends Notifier<int> {
  @override
  int build() => 14;

  void setDays(int days) {
    if (state != days) {
      state = days;
    }
  }
}

final intelligenceWindowDaysProvider =
    NotifierProvider<IntelligenceWindowDaysNotifier, int>(
  IntelligenceWindowDaysNotifier.new,
);

/// Reactive stream provider yielding fresh cross-domain insights whenever data changes.
final lifeIntelligenceProvider = StreamProvider<IntelligenceReport>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(intelligenceServiceProvider);
  final days = ref.watch(intelligenceWindowDaysProvider);

  // Initial calculation
  yield await service.analyzeTimeWindow(days: days);

  // Stream database table updates to auto-refresh insights
  final updateStream = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.studySessions,
      db.screenTimeSnapshots,
      db.entries,
      db.routes,
      db.routineCompletions,
      db.expenses,
    ]),
  );

  await for (final _ in updateStream) {
    yield await service.analyzeTimeWindow(days: days);
  }
});
