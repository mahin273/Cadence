import 'package:drift/drift.dart';

/// Table storing discrete study and deep work focus sessions.
class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get subject => text()();
  TextColumn get tag => text().nullable()();
  TextColumn get sessionType => text()(); // 'work', 'short_break', 'long_break'
  IntColumn get durationSeconds => integer()();
  IntColumn get actualSeconds => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
