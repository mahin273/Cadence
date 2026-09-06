import 'package:drift/drift.dart';

/// Dedicated table for monthly budget thresholds and spending limits.
class Budgets extends Table {
  /// UUID primary key generated client-side.
  TextColumn get id => text()();

  /// Scoped user identifier.
  TextColumn get userId => text()();

  /// Target category (e.g. 'Food', 'Entertainment', 'All').
  TextColumn get category => text()();

  /// Maximum monthly spend target (e.g. 500.0).
  RealColumn get monthlyLimit => real()();

  /// Currency code (e.g. 'USD').
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// Start date of this budget period (typically first day of month).
  DateTimeColumn get startDate => dateTime()();

  /// System creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Modification timestamp for Last-Write-Wins synchronization.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Offline synchronization flag.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Soft deletion flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
