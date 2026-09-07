import 'package:drift/drift.dart';

/// Table storing daily app screen time snapshots queried from native UsageStatsManager.
class ScreenTimeSnapshots extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()(); // Day boundary (e.g. 2026-09-08 00:00:00)
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  TextColumn get category => text()(); // 'social', 'entertainment', 'productivity', 'communication', 'utilities'
  IntColumn get durationMinutes => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
