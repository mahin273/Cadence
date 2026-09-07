import 'package:drift/drift.dart';

/// Table definition for Calendar Events in Drift (SQLite).
@DataClassName('CalendarEvent')
class CalendarEvents extends Table {
  /// Unique client-generated UUID.
  TextColumn get id => text()();

  /// User identifier for multi-tenant / sync isolation.
  TextColumn get userId => text()();

  /// Event title / summary.
  TextColumn get title => text()();

  /// Optional event notes or description.
  TextColumn get description => text().nullable()();

  /// Start timestamp of the event (stored in UTC).
  DateTimeColumn get startTime => dateTime()();

  /// End timestamp of the event (stored in UTC).
  DateTimeColumn get endTime => dateTime()();

  /// Flag indicating if the event occupies the entire day.
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();

  /// Optional ARGB color integer for visual coding.
  IntColumn get colorValue => integer().nullable()();

  /// Category tag: 'work', 'study', 'personal', 'health', 'rest'.
  TextColumn get category => text().withDefault(const Constant('personal'))();

  /// Soft deletion flag for offline-first sync.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Sync flag indicating whether remote Supabase has acknowledged this row.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Timestamp when created locally.
  DateTimeColumn get createdAt => dateTime()();

  /// Timestamp when last updated locally.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
