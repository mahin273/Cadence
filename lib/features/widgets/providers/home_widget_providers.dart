import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../models/widget_sync_data.dart';
import '../services/home_widget_sync_service.dart';

/// Provider for the HomeWidgetSyncService instance.
final homeWidgetSyncServiceProvider = Provider<HomeWidgetSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HomeWidgetSyncService(db);
});

/// Reactive stream provider emitting the latest synchronized WidgetSyncData snapshot.
final activeWidgetSyncDataProvider = StreamProvider<WidgetSyncData>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(homeWidgetSyncServiceProvider);

  // Initial sync
  yield await service.syncWidget();

  // Watch for updates across telemetry tables and re-sync
  final updates = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.studySessions,
      db.entries,
      db.routineCompletions,
      db.routes,
    ]),
  );

  await for (final _ in updates) {
    yield await service.syncWidget();
  }
});
