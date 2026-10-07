import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../models/report_card_models.dart';
import '../services/report_card_service.dart';

/// Provider for the ReportCardService.
final reportCardServiceProvider = Provider<ReportCardService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportCardService(db);
});

/// Notifier for currently selected time range for the visual report card (Week or Month).
class ReportCardTimeRangeNotifier extends Notifier<ReportCardTimeRange> {
  @override
  ReportCardTimeRange build() => ReportCardTimeRange.week;

  void setRange(ReportCardTimeRange range) => state = range;
}

final reportCardTimeRangeProvider =
    NotifierProvider<ReportCardTimeRangeNotifier, ReportCardTimeRange>(
  ReportCardTimeRangeNotifier.new,
);

/// Reactive stream provider for the active report card snapshot.
final reportCardDataProvider = StreamProvider<ReportCardData>((ref) async* {
  final db = ref.watch(appDatabaseProvider);
  final service = ref.watch(reportCardServiceProvider);
  final range = ref.watch(reportCardTimeRangeProvider);

  // Initial calculation
  yield await service.generateReportCard(range: range);

  // Watch for updates across any domain tables
  final updates = db.tableUpdates(
    drift.TableUpdateQuery.onAllTables([
      db.studySessions,
      db.routes,
      db.routineCompletions,
      db.expenses,
      db.entries,
    ]),
  );

  await for (final _ in updates) {
    yield await service.generateReportCard(range: range);
  }
});
