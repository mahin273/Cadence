import 'package:drift/drift.dart';

/// Table storing financial accounts categorized as Assets or Liabilities.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'asset' or 'liability'
  TextColumn get subType => text().withDefault(const Constant('checking'))(); // 'checking', 'savings', 'investment', 'crypto', 'credit_card', 'loan', 'other'
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2196F3))();
  TextColumn get iconName => text().withDefault(const Constant('account_balance_rounded'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Point-in-time balance snapshot history for accounts.
class AccountBalances extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  RealColumn get balance => real()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
