import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/movement/models/route_models.dart';
import 'package:cadence/features/movement/providers/route_recording_provider.dart';
import 'package:cadence/features/movement/widgets/recent_routes_list.dart';
import 'package:cadence/features/movement/widgets/route_recording_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Route Recording UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('RouteRecordingCard renders idle state with activity segments and start button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteRecordingCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Outdoor GPS Tracking'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Cycle'), findsOneWidget);
      expect(find.text('Start Walk'), findsOneWidget);

      // Tap 'Run' segment
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      expect(find.text('Start Run'), findsOneWidget);
    });

    testWidgets('RouteRecordingCard renders active tracking metrics and pause/finish controls',
        (tester) async {
      const activeState = RouteRecordingState(
        routeId: 'active-route-1',
        title: 'Outdoor Run',
        activityType: ActivityType.run,
        status: RouteRecordingStatus.recording,
        durationSeconds: 154, // 2:34
        distanceMeters: 850.0,
        avgPaceSecondsPerKm: 310.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routeRecordingProvider.overrideWith(
              () => _StaticRouteRecordingNotifier(activeState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteRecordingCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LIVE TRACKING'), findsOneWidget);
      expect(find.text('RUN'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('850 m'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('02:34'), findsOneWidget);
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text("5'10\"/km"), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('RouteRecordingCard renders completed summary and Done button',
        (tester) async {
      const completedState = RouteRecordingState(
        routeId: 'completed-route-1',
        title: 'Morning Walk',
        activityType: ActivityType.walk,
        status: RouteRecordingStatus.completed,
        durationSeconds: 1800, // 30:00
        distanceMeters: 2500.0,
        avgPaceSecondsPerKm: 720.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routeRecordingProvider.overrideWith(
              () => _StaticRouteRecordingNotifier(completedState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteRecordingCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Route Complete!'), findsOneWidget);
      expect(find.text('TOTAL DISTANCE'), findsOneWidget);
      expect(find.text('2.50 km'), findsOneWidget);
      expect(find.text('TOTAL TIME'), findsOneWidget);
      expect(find.text('30:00'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('RecentRoutesList renders empty card when no completed routes exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            completedRoutesStreamProvider.overrideWithValue(
              const AsyncValue.data([]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentRoutesList(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Routes'), findsOneWidget);
      expect(find.text('No routes recorded yet'), findsOneWidget);
    });

    testWidgets('RecentRoutesList renders recorded route items when completed routes exist',
        (tester) async {
      final mockRoute = Route(
        id: 'route-mock-1',
        title: 'Morning Jog',
        activityType: 'run',
        status: 'completed',
        startTime: DateTime(2026, 9, 8, 7, 30),
        endTime: DateTime(2026, 9, 8, 8, 0),
        totalDistanceMeters: 4200.0,
        durationSeconds: 1800,
        avgPaceSecondsPerKm: 428.0,
        isSynced: false,
        createdAt: DateTime(2026, 9, 8, 7, 30),
        updatedAt: DateTime(2026, 9, 8, 8, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            completedRoutesStreamProvider.overrideWithValue(
              AsyncValue.data([mockRoute]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecentRoutesList(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Routes'), findsOneWidget);
      expect(find.text('Morning Jog'), findsOneWidget);
      expect(find.text('4.20 km'), findsOneWidget);
      expect(find.textContaining('30:00'), findsOneWidget);
    });
  });
}

class _StaticRouteRecordingNotifier extends RouteRecordingNotifier {
  final RouteRecordingState _initial;

  _StaticRouteRecordingNotifier(this._initial);

  @override
  RouteRecordingState build() {
    return _initial;
  }
}
