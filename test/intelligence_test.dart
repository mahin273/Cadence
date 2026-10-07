import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/features/intelligence/models/life_intelligence_models.dart';
import 'package:cadence/features/intelligence/services/intelligence_engine_service.dart';
import 'package:cadence/features/intelligence/presentation/life_intelligence_screen.dart';

void main() {
  late AppDatabase db;
  late IntelligenceEngineService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = IntelligenceEngineService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('IntelligenceEngineService Unit Tests', () {
    test('Empty database yields zero active days and no spurious insights', () async {
      final report = await service.analyzeTimeWindow(days: 14);

      expect(report.daysAnalyzed, 14);
      expect(report.activeDaysCount, 0);
      expect(report.insights, isEmpty);
      expect(report.strongestCorrelation, isNull);
      expect(report.hasSufficientData, isFalse);
      expect(report.dataCompleteness, 0.0);
    });

    test('Computes cross-domain contrasts accurately for focus, screen time, and hydration', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Day 0 (Today): High Focus, Low Screen Time, High Water, High Movement
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's1',
              subject: 'Engineering',
              durationSeconds: 3600,
              actualSeconds: 5400, // 90 min
              startedAt: today.add(const Duration(hours: 10)),
              completedAt: Value(today.add(const Duration(hours: 11, minutes: 30))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st1',
              date: today,
              packageName: 'com.example.app',
              appName: 'App',
              category: 'social',
              durationMinutes: 60,
            ),
          );
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w1',
              userId: 'user1',
              type: 'water',
              value: 8.0,
              occurredAt: today.add(const Duration(hours: 8)),
            ),
          );
      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'r1',
              startTime: today.add(const Duration(hours: 7)),
              totalDistanceMeters: const Value(5000.0),
              durationSeconds: const Value(1800),
            ),
          );

      // Day 1 (Yesterday): High Focus, Low Screen Time, High Water, High Movement
      final yesterday = today.subtract(const Duration(days: 1));
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's2',
              subject: 'Mathematics',
              durationSeconds: 3600,
              actualSeconds: 7200, // 120 min
              startedAt: yesterday.add(const Duration(hours: 14)),
              completedAt: Value(yesterday.add(const Duration(hours: 16))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st2',
              date: yesterday,
              packageName: 'com.example.app',
              appName: 'App',
              category: 'social',
              durationMinutes: 70,
            ),
          );
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w2',
              userId: 'user1',
              type: 'water',
              value: 7.0,
              occurredAt: yesterday.add(const Duration(hours: 9)),
            ),
          );
      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'r2',
              startTime: yesterday.add(const Duration(hours: 18)),
              totalDistanceMeters: const Value(4500.0),
              durationSeconds: const Value(1600),
            ),
          );

      // Day 2 (Two days ago): Low Focus, High Screen Time, Low Water, Low Movement
      final day2 = today.subtract(const Duration(days: 2));
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's3',
              subject: 'Reading',
              durationSeconds: 1200,
              actualSeconds: 600, // 10 min
              startedAt: day2.add(const Duration(hours: 15)),
              completedAt: Value(day2.add(const Duration(hours: 15, minutes: 10))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st3',
              date: day2,
              packageName: 'com.example.app',
              appName: 'App',
              category: 'entertainment',
              durationMinutes: 240, // 4 hours
            ),
          );
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w3',
              userId: 'user1',
              type: 'water',
              value: 2.0,
              occurredAt: day2.add(const Duration(hours: 12)),
            ),
          );
      await db.into(db.routes).insert(
            RoutesCompanion.insert(
              id: 'r3',
              startTime: day2.add(const Duration(hours: 19)),
              totalDistanceMeters: const Value(600.0),
              durationSeconds: const Value(300),
            ),
          );

      // Analyze 7-day window
      final report = await service.analyzeTimeWindow(days: 7);

      expect(report.activeDaysCount, 3);
      expect(report.hasSufficientData, isTrue);
      expect(report.insights, isNotEmpty);

      // Check Focus vs Screen Time Insight
      final focusInsight = report.insights.firstWhere(
        (i) => i.category == InsightCategory.focusVsScreenTime,
      );
      expect(focusInsight.title, 'Deep Work & Screen Time');
      expect(focusInsight.contrastPercent, lessThan(0)); // Screen time drops on high focus days
      expect(focusInsight.isStatisticallyMeaningful, isTrue);

      // Check Hydration vs Movement Insight
      final hydroInsight = report.insights.firstWhere(
        (i) => i.category == InsightCategory.hydrationVsMovement,
      );
      expect(hydroInsight.title, 'Hydration & Daily Mobility');
      expect(hydroInsight.contrastPercent, greaterThan(0)); // Movement distance increases on hydrated days
      expect(hydroInsight.isStatisticallyMeaningful, isTrue);

      expect(report.strongestCorrelation, isNotNull);
    });
  });

  group('LifeIntelligenceScreen Widget Tests', () {
    testWidgets('Renders empty/gathering state cleanly on fresh database', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: LifeIntelligenceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Intelligence'), findsOneWidget);
      expect(find.text('Offline Rhythm Intelligence'), findsOneWidget);
      expect(find.text('Gathering Behavioral Rhythm'), findsOneWidget);
      expect(find.text('0 of 3 baseline active days logged'), findsOneWidget);
    });

    testWidgets('Renders discovered insights when data is present', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final day2 = today.subtract(const Duration(days: 2));

      // Day 0
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's1',
              subject: 'Deep Work',
              durationSeconds: 3600,
              actualSeconds: 6000,
              startedAt: today,
              completedAt: Value(today.add(const Duration(hours: 2))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st1',
              date: today,
              packageName: 'app',
              appName: 'App',
              category: 'social',
              durationMinutes: 45,
            ),
          );

      // Day 1
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's2',
              subject: 'Deep Work',
              durationSeconds: 3600,
              actualSeconds: 5400,
              startedAt: yesterday,
              completedAt: Value(yesterday.add(const Duration(hours: 2))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st2',
              date: yesterday,
              packageName: 'app',
              appName: 'App',
              category: 'social',
              durationMinutes: 50,
            ),
          );

      // Day 2
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's3',
              subject: 'Deep Work',
              durationSeconds: 1200,
              actualSeconds: 600,
              startedAt: day2,
              completedAt: Value(day2.add(const Duration(minutes: 10))),
              sessionType: 'work',
            ),
          );
      await db.into(db.screenTimeSnapshots).insert(
            ScreenTimeSnapshotsCompanion.insert(
              id: 'st3',
              date: day2,
              packageName: 'app',
              appName: 'App',
              category: 'social',
              durationMinutes: 220,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: LifeIntelligenceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Intelligence'), findsOneWidget);
      expect(find.text('Discovered Life Patterns'), findsOneWidget);
      expect(find.text('Deep Work & Screen Time'), findsOneWidget);
    });
  });
}
