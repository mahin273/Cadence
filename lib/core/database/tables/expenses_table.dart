import 'package:drift/drift.dart';
import '../converters/json_converters.dart';

/// Dedicated table for financial expense tracking.
class Expenses extends Table {
  /// UUID primary key generated client-side for offline collision resistance.
  TextColumn get id => text()();

  /// Scoped user identifier for multi-user / family workloads and RLS.
  TextColumn get userId => text()();

  /// Financial monetary value (e.g. 15.50).
  RealColumn get amount => real()();

  /// ISO 4217 Currency code (e.g. 'USD', 'EUR').
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// High-level category (e.g. 'Food', 'Transport', 'Housing', 'Entertainment', 'Health', 'Shopping', 'Utilities', 'Other').
  TextColumn get category => text()();

  /// User notes or merchant description.
  TextColumn get note => text().nullable()();

  /// Local filesystem path or URI to attached receipt image.
  TextColumn get receiptPath => text().nullable()();

  /// Arbitrary search tags serialized as JSON string.
  TextColumn get tags =>
      text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Timestamp when transaction occurred.
  DateTimeColumn get occurredAt => dateTime()();

  /// System creation timestamp.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Modification timestamp for Last-Write-Wins synchronization.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Offline synchronization flag.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Soft deletion flag to propagate deletions across devices.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
