import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/app_database.dart';
import '../models/report_card_models.dart';

/// Aggregation and export engine producing shareable visual summaries and CSV exports.
class ReportCardService {
  final AppDatabase db;

  ReportCardService(this.db);

  /// Generates multi-domain aggregated telemetry and grades consistency.
  Future<ReportCardData> generateReportCard({
    required ReportCardTimeRange range,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final startDate = today.subtract(Duration(days: range.days - 1));
    final endDate = today.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    // 1. Study Sessions
    final studySessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(startDate) &
              tbl.startedAt.isSmallerOrEqualValue(endDate)))
        .get();

    int totalFocusMinutes = 0;
    int completedFocusSessions = 0;
    final Set<DateTime> activeDates = {};

    DateTime toDateKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    for (final s in studySessions) {
      final mins = s.actualSeconds ~/ 60;
      totalFocusMinutes += mins;
      if (s.sessionType == 'work') {
        completedFocusSessions++;
      }
      if (mins > 0) {
        activeDates.add(toDateKey(s.startedAt));
      }
    }

    // 2. Routes (Movement)
    final routes = await (db.select(db.routes)
          ..where((tbl) =>
              tbl.startTime.isBiggerOrEqualValue(startDate) &
              tbl.startTime.isSmallerOrEqualValue(endDate)))
        .get();

    double totalMovementMeters = 0.0;
    for (final r in routes) {
      totalMovementMeters += r.totalDistanceMeters;
      activeDates.add(toDateKey(r.startTime));
    }
    final totalMovementKm = totalMovementMeters / 1000.0;

    // 3. Routine Completions
    final completions = await (db.select(db.routineCompletions)
          ..where((tbl) =>
              tbl.completedAt.isBiggerOrEqualValue(startDate) &
              tbl.completedAt.isSmallerOrEqualValue(endDate)))
        .get();

    for (final c in completions) {
      activeDates.add(toDateKey(c.completedAt));
    }

    // 4. Expenses
    final expenses = await (db.select(db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startDate) &
              tbl.occurredAt.isSmallerOrEqualValue(endDate)))
        .get();

    double totalExpenses = 0.0;
    for (final exp in expenses) {
      totalExpenses += exp.amount;
    }

    // 5. Entries (Water & Habits)
    final entries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(startDate) &
              tbl.occurredAt.isSmallerOrEqualValue(endDate) &
              tbl.isDeleted.equals(false)))
        .get();

    double totalWaterGlasses = 0.0;
    for (final e in entries) {
      if (e.type == 'water') {
        totalWaterGlasses += e.value;
      }
      activeDates.add(toDateKey(e.occurredAt));
    }

    // Calculate Consistency Rate & Grade
    final activeDaysCount = activeDates.length;
    final double consistencyPct =
        (activeDaysCount / range.days * 100.0).clamp(0.0, 100.0);

    final String grade;
    if (consistencyPct >= 90.0) {
      grade = 'A+';
    } else if (consistencyPct >= 80.0) {
      grade = 'A';
    } else if (consistencyPct >= 70.0) {
      grade = 'B';
    } else if (consistencyPct >= 50.0) {
      grade = 'C';
    } else {
      grade = 'Needs Momentum';
    }

    // Contextual highlights
    final List<String> highlights = [];
    if (totalFocusMinutes > 0) {
      final hours = (totalFocusMinutes / 60.0).toStringAsFixed(1);
      highlights.add('$hours hrs deep focus completed across $completedFocusSessions sessions');
    }
    if (totalMovementKm > 0) {
      highlights.add('${totalMovementKm.toStringAsFixed(1)} km recorded across outdoor mobility');
    }
    if (completions.isNotEmpty) {
      highlights.add('${completions.length} daily checklist routines executed');
    }
    if (totalWaterGlasses > 0) {
      highlights.add('${totalWaterGlasses.toStringAsFixed(0)} glasses of hydration logged');
    }
    if (totalExpenses > 0) {
      highlights.add('\$${totalExpenses.toStringAsFixed(2)} total expenditure tracked');
    }
    if (highlights.isEmpty) {
      highlights.add('No activities logged yet in this time window');
    }

    return ReportCardData(
      title: range == ReportCardTimeRange.week
          ? 'Weekly Cadence Report Card'
          : 'Monthly Cadence Report Card',
      startDate: startDate,
      endDate: today,
      totalFocusMinutes: totalFocusMinutes,
      completedFocusSessions: completedFocusSessions,
      totalMovementKm: double.parse(totalMovementKm.toStringAsFixed(2)),
      completedRoutinesCount: completions.length,
      totalExpenses: double.parse(totalExpenses.toStringAsFixed(2)),
      totalWaterGlasses: double.parse(totalWaterGlasses.toStringAsFixed(1)),
      activeDaysCount: activeDaysCount,
      totalDaysCount: range.days,
      currentStreak: activeDaysCount > 0 ? activeDaysCount : 0,
      longestStreak: activeDaysCount > 0 ? activeDaysCount : 0,
      consistencyGrade: grade,
      consistencyPercentage: double.parse(consistencyPct.toStringAsFixed(1)),
      highlights: highlights,
    );
  }

  /// Formats clean shareable plain text summary of the report card.
  String formatShareableTextReport(ReportCardData report) {
    final df = DateFormat('MMM d, yyyy');
    final startStr = df.format(report.startDate);
    final endStr = df.format(report.endDate);
    final focusHours = (report.totalFocusMinutes / 60.0).toStringAsFixed(1);

    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('CADENCE LIFE REPORT CARD');
    buffer.writeln('$startStr - $endStr');
    buffer.writeln('========================================');
    buffer.writeln('Consistency Grade: ${report.consistencyGrade} (${report.consistencyPercentage}%)');
    buffer.writeln('Active Days: ${report.activeDaysCount} of ${report.totalDaysCount}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('DOMAINS SUMMARY:');
    buffer.writeln('- Deep Focus: ${focusHours}h (${report.completedFocusSessions} sessions)');
    buffer.writeln('- Movement: ${report.totalMovementKm} km');
    buffer.writeln('- Routines: ${report.completedRoutinesCount} completed');
    buffer.writeln('- Hydration: ${report.totalWaterGlasses.toStringAsFixed(0)} glasses');
    buffer.writeln('- Expenses: \$${report.totalExpenses.toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('KEY HIGHLIGHTS:');
    for (final h in report.highlights) {
      buffer.writeln('- $h');
    }
    buffer.writeln('========================================');
    buffer.writeln('Generated locally by Cadence (Offline Intelligence)');
    return buffer.toString();
  }

  /// Generates CSV format for historical expenses.
  Future<String> generateExpensesCsv({
    required DateTime start,
    required DateTime end,
  }) async {
    final expenses = await (db.select(db.expenses)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(start) &
              tbl.occurredAt.isSmallerOrEqualValue(end)))
        .get();

    final buffer = StringBuffer();
    buffer.writeln('id,occurred_at,category,amount,currency,note,tags');

    for (final exp in expenses) {
      final safeNote = _escapeCsv(exp.note ?? '');
      final safeTags = _escapeCsv(exp.tags.join(';'));
      buffer.writeln(
        '${exp.id},${exp.occurredAt.toIso8601String()},${_escapeCsv(exp.category)},${exp.amount},${exp.currency},$safeNote,$safeTags',
      );
    }
    return buffer.toString();
  }

  /// Generates CSV format for study and focus sessions.
  Future<String> generateStudyCsv({
    required DateTime start,
    required DateTime end,
  }) async {
    final sessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(start) &
              tbl.startedAt.isSmallerOrEqualValue(end)))
        .get();

    final buffer = StringBuffer();
    buffer.writeln('id,started_at,completed_at,subject,session_type,target_minutes,actual_minutes,tag');

    for (final s in sessions) {
      final targetMins = s.durationSeconds ~/ 60;
      final actualMins = s.actualSeconds ~/ 60;
      buffer.writeln(
        '${s.id},${s.startedAt.toIso8601String()},${s.completedAt?.toIso8601String() ?? ""},${_escapeCsv(s.subject)},${s.sessionType},$targetMins,$actualMins,${_escapeCsv(s.tag ?? "")}',
      );
    }
    return buffer.toString();
  }

  /// Generates unified multi-domain daily telemetry CSV.
  Future<String> generateTelemetryCsv({
    required DateTime start,
    required DateTime end,
  }) async {
    final daysCount = end.difference(start).inDays + 1;
    final buffer = StringBuffer();
    buffer.writeln('date,focus_minutes,movement_meters,water_glasses,expenses_amount,routines_completed');

    for (int i = 0; i < daysCount; i++) {
      final day = start.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

      final sessions = await (db.select(db.studySessions)
            ..where((tbl) =>
                tbl.startedAt.isBiggerOrEqualValue(dayStart) &
                tbl.startedAt.isSmallerOrEqualValue(dayEnd)))
          .get();
      final focusMins =
          sessions.fold(0, (sum, s) => sum + (s.actualSeconds ~/ 60));

      final routes = await (db.select(db.routes)
            ..where((tbl) =>
                tbl.startTime.isBiggerOrEqualValue(dayStart) &
                tbl.startTime.isSmallerOrEqualValue(dayEnd)))
          .get();
      final moveMeters =
          routes.fold(0.0, (sum, r) => sum + r.totalDistanceMeters);

      final entries = await (db.select(db.entries)
            ..where((tbl) =>
                tbl.type.equals('water') &
                tbl.occurredAt.isBiggerOrEqualValue(dayStart) &
                tbl.occurredAt.isSmallerOrEqualValue(dayEnd) &
                tbl.isDeleted.equals(false)))
          .get();
      final water = entries.fold(0.0, (sum, e) => sum + e.value);

      final expenses = await (db.select(db.expenses)
            ..where((tbl) =>
                tbl.occurredAt.isBiggerOrEqualValue(dayStart) &
                tbl.occurredAt.isSmallerOrEqualValue(dayEnd)))
          .get();
      final exp = expenses.fold(0.0, (sum, e) => sum + e.amount);

      final completions = await (db.select(db.routineCompletions)
            ..where((tbl) =>
                tbl.completedAt.isBiggerOrEqualValue(dayStart) &
                tbl.completedAt.isSmallerOrEqualValue(dayEnd)))
          .get();

      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      buffer.writeln(
        '$dateStr,$focusMins,$moveMeters,$water,$exp,${completions.length}',
      );
    }
    return buffer.toString();
  }

  /// Exports CSV content to temporary file and triggers platform share sheet.
  Future<void> exportAndShareCsv({
    required String filename,
    required String csvContent,
    String? subject,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csvContent);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject ?? 'Cadence CSV Export: $filename',
      ),
    );
  }

  /// Dispatches plain text summary via platform share sheet.
  Future<void> shareTextReport(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject ?? 'Cadence Life Report Card',
      ),
    );
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
