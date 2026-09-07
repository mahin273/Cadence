import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Custom Drift serializer capable of converting complex JSON array/map types
/// into typed Dart collections (e.g. `List<String>`, `Map<String, dynamic>`).
class CadenceValueSerializer extends ValueSerializer {
  const CadenceValueSerializer();

  @override
  T fromJson<T>(dynamic json) {
    if (json == null) {
      return null as T;
    }

    final typeList = <T>[];

    if (typeList is List<DateTime?>) {
      if (json is int) {
        return DateTime.fromMillisecondsSinceEpoch(json) as T;
      } else {
        return DateTime.parse(json.toString()) as T;
      }
    }

    if (typeList is List<double?> && json is int) {
      return json.toDouble() as T;
    }

    if (typeList is List<Uint8List?> && json is! Uint8List) {
      final asList = (json as List).cast<int>();
      return Uint8List.fromList(asList) as T;
    }

    if (typeList is List<List<String>?> && json is List) {
      return json.map((e) => e.toString()).toList() as T;
    }

    if (typeList is List<Map<String, dynamic>?> && json is Map) {
      return Map<String, dynamic>.from(json) as T;
    }

    return json as T;
  }

  @override
  dynamic toJson<T>(T value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }
}

/// Service providing universal JSON database export and transactional restoration.
class DataExportService {
  final AppDatabase _db;
  static const serializer = CadenceValueSerializer();

  const DataExportService(this._db);

  /// Export the entire database across all 18 tables into formatted JSON.
  Future<String> exportAllDataAsJson() async {
    final entries = await _db.select(_db.entries).get();
    final expenses = await _db.select(_db.expenses).get();
    final budgets = await _db.select(_db.budgets).get();
    final goals = await _db.select(_db.goals).get();
    final goalRecords = await _db.select(_db.goalRecords).get();
    final calendarEvents = await _db.select(_db.calendarEvents).get();
    final routes = await _db.select(_db.routes).get();
    final routePoints = await _db.select(_db.routePoints).get();
    final routines = await _db.select(_db.routines).get();
    final routineItems = await _db.select(_db.routineItems).get();
    final routineCompletions = await _db.select(_db.routineCompletions).get();
    final studySessions = await _db.select(_db.studySessions).get();
    final weeklyReviews = await _db.select(_db.weeklyReviews).get();
    final accounts = await _db.select(_db.accounts).get();
    final accountBalances = await _db.select(_db.accountBalances).get();
    final debts = await _db.select(_db.debts).get();
    final debtPayments = await _db.select(_db.debtPayments).get();
    final screenTimeSnapshots = await _db.select(_db.screenTimeSnapshots).get();

    final payload = {
      'version': 1,
      'app': 'Cadence',
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'entries': entries.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'budgets': budgets.map((e) => e.toJson()).toList(),
        'goals': goals.map((e) => e.toJson()).toList(),
        'goalRecords': goalRecords.map((e) => e.toJson()).toList(),
        'calendarEvents': calendarEvents.map((e) => e.toJson()).toList(),
        'routes': routes.map((e) => e.toJson()).toList(),
        'routePoints': routePoints.map((e) => e.toJson()).toList(),
        'routines': routines.map((e) => e.toJson()).toList(),
        'routineItems': routineItems.map((e) => e.toJson()).toList(),
        'routineCompletions': routineCompletions.map((e) => e.toJson()).toList(),
        'studySessions': studySessions.map((e) => e.toJson()).toList(),
        'weeklyReviews': weeklyReviews.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'accountBalances': accountBalances.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'debtPayments': debtPayments.map((e) => e.toJson()).toList(),
        'screenTimeSnapshots': screenTimeSnapshots.map((e) => e.toJson()).toList(),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Import and restore data from a Cadence JSON backup inside an atomic transaction.
  Future<bool> importDataFromJson(String jsonString, {bool clearExisting = true}) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    final version = decoded['version'] as int? ?? 1;
    if (version < 1) return false;

    final tables = decoded['tables'] as Map<String, dynamic>?;
    if (tables == null) return false;

    await _db.transaction(() async {
      if (clearExisting) {
        // Clear child tables first to respect foreign keys
        await _db.delete(_db.debtPayments).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.accountBalances).go();
        await _db.delete(_db.accounts).go();
        await _db.delete(_db.weeklyReviews).go();
        await _db.delete(_db.studySessions).go();
        await _db.delete(_db.routineCompletions).go();
        await _db.delete(_db.routineItems).go();
        await _db.delete(_db.routines).go();
        await _db.delete(_db.routePoints).go();
        await _db.delete(_db.routes).go();
        await _db.delete(_db.calendarEvents).go();
        await _db.delete(_db.goalRecords).go();
        await _db.delete(_db.goals).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.expenses).go();
        await _db.delete(_db.entries).go();
        await _db.delete(_db.screenTimeSnapshots).go();
      }

      await _db.batch((b) {
        // Parent tables first, then children
        if (tables['entries'] != null) {
          final list = (tables['entries'] as List)
              .map((m) => Entry.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.entries, list);
        }
        if (tables['expenses'] != null) {
          final list = (tables['expenses'] as List)
              .map((m) => Expense.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.expenses, list);
        }
        if (tables['budgets'] != null) {
          final list = (tables['budgets'] as List)
              .map((m) => Budget.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.budgets, list);
        }
        if (tables['goals'] != null) {
          final list = (tables['goals'] as List)
              .map((m) => Goal.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.goals, list);
        }
        if (tables['goalRecords'] != null) {
          final list = (tables['goalRecords'] as List)
              .map((m) => GoalRecord.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.goalRecords, list);
        }
        if (tables['calendarEvents'] != null) {
          final list = (tables['calendarEvents'] as List)
              .map((m) => CalendarEvent.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.calendarEvents, list);
        }
        if (tables['routes'] != null) {
          final list = (tables['routes'] as List)
              .map((m) => Route.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.routes, list);
        }
        if (tables['routePoints'] != null) {
          final list = (tables['routePoints'] as List)
              .map((m) => RoutePoint.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.routePoints, list);
        }
        if (tables['routines'] != null) {
          final list = (tables['routines'] as List)
              .map((m) => Routine.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.routines, list);
        }
        if (tables['routineItems'] != null) {
          final list = (tables['routineItems'] as List)
              .map((m) => RoutineItem.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.routineItems, list);
        }
        if (tables['routineCompletions'] != null) {
          final list = (tables['routineCompletions'] as List)
              .map((m) => RoutineCompletion.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.routineCompletions, list);
        }
        if (tables['studySessions'] != null) {
          final list = (tables['studySessions'] as List)
              .map((m) => StudySession.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.studySessions, list);
        }
        if (tables['weeklyReviews'] != null) {
          final list = (tables['weeklyReviews'] as List)
              .map((m) => WeeklyReview.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.weeklyReviews, list);
        }
        if (tables['accounts'] != null) {
          final list = (tables['accounts'] as List)
              .map((m) => Account.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.accounts, list);
        }
        if (tables['accountBalances'] != null) {
          final list = (tables['accountBalances'] as List)
              .map((m) => AccountBalance.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.accountBalances, list);
        }
        if (tables['debts'] != null) {
          final list = (tables['debts'] as List)
              .map((m) => Debt.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.debts, list);
        }
        if (tables['debtPayments'] != null) {
          final list = (tables['debtPayments'] as List)
              .map((m) => DebtPayment.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.debtPayments, list);
        }
        if (tables['screenTimeSnapshots'] != null) {
          final list = (tables['screenTimeSnapshots'] as List)
              .map((m) => ScreenTimeSnapshot.fromJson(
                    Map<String, dynamic>.from(m as Map),
                    serializer: serializer,
                  ))
              .toList();
          b.insertAll(_db.screenTimeSnapshots, list);
        }
      });
    });

    return true;
  }

  /// Query record counts across all core tables.
  Future<Map<String, int>> getDatabaseStatistics() async {
    final entriesCount = await _db.select(_db.entries).get().then((l) => l.length);
    final expensesCount = await _db.select(_db.expenses).get().then((l) => l.length);
    final routesCount = await _db.select(_db.routes).get().then((l) => l.length);
    final routinesCount = await _db.select(_db.routines).get().then((l) => l.length);
    final studySessionsCount = await _db.select(_db.studySessions).get().then((l) => l.length);
    final accountsCount = await _db.select(_db.accounts).get().then((l) => l.length);
    final debtsCount = await _db.select(_db.debts).get().then((l) => l.length);
    final screenTimeCount = await _db.select(_db.screenTimeSnapshots).get().then((l) => l.length);

    final total = entriesCount +
        expensesCount +
        routesCount +
        routinesCount +
        studySessionsCount +
        accountsCount +
        debtsCount +
        screenTimeCount;

    return {
      'entries': entriesCount,
      'expenses': expensesCount,
      'routes': routesCount,
      'routines': routinesCount,
      'studySessions': studySessionsCount,
      'accounts': accountsCount,
      'debts': debtsCount,
      'screenTime': screenTimeCount,
      'total': total,
    };
  }
}
