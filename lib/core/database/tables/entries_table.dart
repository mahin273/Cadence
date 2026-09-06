import 'package:drift/drift.dart';
import '../converters/json_converters.dart';

/// The polymorphic shared entries table (habits, journal, water, sleep, mood, screen-time).
@DataClassName('Entry')
class Entries extends Table {
  /// Unique client-generated UUID primary key.
  TextColumn get id => text()();

  /// User UUID (synced with Supabase Auth GoTrue user ID).
  TextColumn get userId => text()();

  /// Entry type discriminator ('water' | 'sleep' | 'mood' | 'habit' | 'journal' | 'screen_time').
  TextColumn get type => text()();

  /// Quantitative value (e.g. 8.0 glasses, 7.5 hours, 4.0 mood rating).
  RealColumn get value => real()();

  /// Optional measurement unit ('glasses', 'hours', 'rating', 'count').
  TextColumn get unit => text().nullable()();

  /// Optional user notes or journal content.
  TextColumn get note => text().nullable()();

  /// Array of tags for cross-module queries (e.g. ['Thesis', 'Health']).
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  /// Extra type-specific attributes encoded as JSON map.
  TextColumn get metadata => text().map(const JsonMapConverter()).nullable()();

  /// When the activity occurred in the real world.
  DateTimeColumn get occurredAt => dateTime()();

  /// Audit timestamp when created on client.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Timestamp when last updated (used for last-write-wins sync resolution).
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether this row has been pushed to remote Supabase DB.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Soft delete flag to propagate deletions to remote Supabase DB.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
