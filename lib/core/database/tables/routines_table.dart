import 'package:drift/drift.dart';

/// SQLite table for structured daily routines (templates).
class Routines extends Table {
  /// Unique routine identifier (UUID).
  TextColumn get id => text()();

  /// User-visible title (e.g. "Morning Launchpad", "Deep Work Setup").
  TextColumn get title => text()();

  /// Optional description or rationale for this routine.
  TextColumn get description => text().nullable()();

  /// Circadian phase / time of day: 'morning', 'afternoon', 'evening', 'anytime'.
  TextColumn get timeOfDay => text().withDefault(const Constant('morning'))();

  /// Material icon identifier string.
  TextColumn get iconName => text().withDefault(const Constant('wb_sunny_rounded'))();

  /// ARGB color representation for visual theming.
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF2196F3))();

  /// Display ordering index among routines.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Active status flag (false = archived).
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Record creation timestamp.
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  /// Record last-modified timestamp.
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// SQLite table for individual checklist steps belonging to a routine.
class RoutineItems extends Table {
  /// Unique checklist item identifier (UUID).
  TextColumn get id => text()();

  /// Parent routine foreign key with cascade deletion.
  TextColumn get routineId => text().references(Routines, #id, onDelete: KeyAction.cascade)();

  /// Task label (e.g. "Drink 500ml Water", "10-minute mobility").
  TextColumn get title => text()();

  /// Estimated duration in minutes.
  IntColumn get durationMinutes => integer().withDefault(const Constant(5))();

  /// Sequential step index within the parent routine.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether this task is mandatory for 100% routine completion.
  BoolColumn get isRequired => boolean().withDefault(const Constant(true))();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only log of daily checklist step completions.
class RoutineCompletions extends Table {
  /// Sequential primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Parent routine foreign key.
  TextColumn get routineId => text().references(Routines, #id, onDelete: KeyAction.cascade)();

  /// Completed checklist item foreign key.
  TextColumn get itemId => text().references(RoutineItems, #id, onDelete: KeyAction.cascade)();

  /// Local calendar date string formatted as 'YYYY-MM-DD'.
  TextColumn get completedDate => text()();

  /// Precise execution timestamp.
  DateTimeColumn get completedAt => dateTime().clientDefault(() => DateTime.now())();
}
