import 'package:drift/drift.dart';

/// Goals table storing user-defined targets across modules (water, spend, steps, study, habits).
@DataClassName('Goal')
class Goals extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Scoped user ID for multi-user tenancy and RLS.
  TextColumn get userId => text()();

  /// Human-readable title (e.g., "Daily Water Intake", "Daily Spending Limit").
  TextColumn get title => text()();

  /// Goal category / module type ('water', 'spend', 'steps', 'study', 'habit', 'custom').
  TextColumn get goalType => text()();

  /// Numeric target to achieve (e.g. 8.0 for water, 50.0 for spend).
  RealColumn get targetValue => real()();

  /// Optional display unit (e.g. 'glasses', '$', 'hours', 'steps', 'times').
  TextColumn get unit => text().nullable()();

  /// Recurrence period ('daily' or 'weekly'). Default is 'daily'.
  TextColumn get period => text().withDefault(const Constant('daily'))();

  /// Directionality ('at_least' for progress, 'at_most' for caps/limits). Default is 'at_least'.
  TextColumn get targetType => text().withDefault(const Constant('at_least'))();

  /// Whether the goal is currently tracked.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Sync timestamp with remote Supabase DB.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Offline sync status flags.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// GoalRecords table storing manual progress check-ins or override values for custom goals.
@DataClassName('GoalRecord')
class GoalRecords extends Table {
  /// UUID primary key.
  TextColumn get id => text()();

  /// Foreign key referencing Goals.id.
  TextColumn get goalId => text().references(Goals, #id)();

  /// Scoped user ID.
  TextColumn get userId => text()();

  /// Calendar day of the progress record (midnight normalized).
  DateTimeColumn get date => dateTime()();

  /// Amount achieved on that day.
  RealColumn get achievedValue => real()();

  /// Whether the target was met on that day.
  BoolColumn get isHit => boolean()();

  /// Sync timestamps and flags.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
