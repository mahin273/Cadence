import 'package:drift/drift.dart';

/// SQLite table definition for Outdoor GPS Activity Routes.
class Routes extends Table {
  /// Unique route identifier (UUID v4).
  TextColumn get id => text()();

  /// User-visible title (e.g. "Morning Run", "Neighborhood Walk").
  TextColumn get title => text().withDefault(const Constant('Outdoor Activity'))();

  /// Activity type: 'walk', 'run', 'cycle'.
  TextColumn get activityType => text().withDefault(const Constant('walk'))();

  /// Session status: 'recording', 'paused', 'completed', 'cancelled'.
  TextColumn get status => text().withDefault(const Constant('recording'))();

  /// Session start timestamp.
  DateTimeColumn get startTime => dateTime()();

  /// Session completion timestamp (null while in progress).
  DateTimeColumn get endTime => dateTime().nullable()();

  /// Total cumulative distance traversed in meters.
  RealColumn get totalDistanceMeters => real().withDefault(const Constant(0.0))();

  /// Total moving duration in seconds.
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();

  /// Average pace in seconds per kilometer.
  RealColumn get avgPaceSecondsPerKm => real().withDefault(const Constant(0.0))();

  /// Sync flag for future remote synchronization (Chunk 15 PostGIS).
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Record creation timestamp.
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  /// Record last-modified timestamp.
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// SQLite table definition for recorded GPS breadcrumb points.
class RoutePoints extends Table {
  /// Sequential primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key referencing the parent Route session.
  TextColumn get routeId => text().references(Routes, #id, onDelete: KeyAction.cascade)();

  /// Latitude in decimal degrees.
  RealColumn get latitude => real()();

  /// Longitude in decimal degrees.
  RealColumn get longitude => real()();

  /// Altitude in meters above sea level (optional).
  RealColumn get altitude => real().nullable()();

  /// Instantaneous speed in meters per second (optional).
  RealColumn get speed => real().nullable()();

  /// Estimated horizontal accuracy radius in meters.
  RealColumn get accuracy => real().nullable()();

  /// Timestamp when the GPS reading was captured.
  DateTimeColumn get timestamp => dateTime()();

  /// Zero-based sequential ordering index within the route.
  IntColumn get pointIndex => integer()();
}
