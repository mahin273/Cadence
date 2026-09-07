import 'package:drift/drift.dart';

/// Table storing interpersonal debts (lent to others or borrowed from others).
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get personName => text()();
  TextColumn get type => text()(); // 'lent' (owed to me) or 'borrowed' (I owe)
  RealColumn get initialAmount => real()();
  RealColumn get remainingAmount => real()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table storing incremental payments made against debts.
class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text().references(Debts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  DateTimeColumn get paidAt => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
