import 'package:drift/drift.dart';

/// Table storing historical weekly review summaries, composite scores, and reflections.
class WeeklyReviews extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get weekStartDate => dateTime()();
  DateTimeColumn get weekEndDate => dateTime()();
  IntColumn get compositeScore => integer()();
  TextColumn get summaryJson => text()();
  TextColumn get reflectionNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
