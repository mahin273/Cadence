import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/movement/providers/route_recording_provider.dart';
import 'package:cadence/features/movement/widgets/recent_routes_list.dart';
import 'package:cadence/features/movement/widgets/route_detail_sheet.dart';
import 'package:cadence/features/movement/widgets/route_map_view.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteMapView Tests', () {
    testWidgets('RouteMapView renders empty placeholder when points list is empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouteMapView(points: []),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No GPS coordinates recorded for this route'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('RouteMapView renders FlutterMap with single point without bounds error',
        (tester) async {
      final singlePoint = RoutePoint(
        id: 1,
        routeId: 'route-single',
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        pointIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteMapView(points: [singlePoint]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing); // Single point doesn't have polyline
      expect(find.byType(MarkerLayer), findsOneWidget);
    });

    testWidgets('RouteMapView renders FlutterMap, PolylineLayer, and Markers for multiple points',
        (tester) async {
      final points = [
        RoutePoint(
          id: 1,
          routeId: 'route-multi',
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          pointIndex: 0,
        ),
        RoutePoint(
          id: 2,
          routeId: 'route-multi',
          latitude: 37.7755,
          longitude: -122.4180,
          timestamp: DateTime.now().add(const Duration(seconds: 10)),
          pointIndex: 1,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteMapView(points: points),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
    });
  });

  group('RouteDetailSheet Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('RouteDetailSheet renders route telemetry and map',
        (tester) async {
      final mockRoute = Route(
        id: 'route-detail-test',
        title: 'Sunset Trail Run',
        activityType: 'run',
        status: 'completed',
        startTime: DateTime(2026, 9, 8, 18, 0),
        endTime: DateTime(2026, 9, 8, 18, 45),
        totalDistanceMeters: 5500.0,
        durationSeconds: 2700, // 45:00
        avgPaceSecondsPerKm: 490.0, // ~8'10"/km
        isSynced: false,
        createdAt: DateTime(2026, 9, 8, 18, 0),
        updatedAt: DateTime(2026, 9, 8, 18, 45),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routePointsFutureProvider(mockRoute.id).overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteDetailSheet(route: mockRoute),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sunset Trail Run'), findsOneWidget);
      expect(find.text('5.50 km'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      expect(find.text("8'10\"/km"), findsOneWidget);
      expect(find.text('Local Only'), findsOneWidget);
    });

    testWidgets('Tapping route in RecentRoutesList opens RouteDetailSheet modal',
        (tester) async {
      final mockRoute = Route(
        id: 'route-tap-test',
        title: 'Neighborhood Walk',
        activityType: 'walk',
        status: 'completed',
        startTime: DateTime(2026, 9, 8, 9, 0),
        endTime: DateTime(2026, 9, 8, 9, 30),
        totalDistanceMeters: 1800.0,
        durationSeconds: 1800,
        avgPaceSecondsPerKm: 1000.0,
        isSynced: true,
        createdAt: DateTime(2026, 9, 8, 9, 0),
        updatedAt: DateTime(2026, 9, 8, 9, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            completedRoutesStreamProvider.overrideWithValue(
              AsyncValue.data([mockRoute]),
            ),
            routePointsFutureProvider(mockRoute.id).overrideWith(
              (ref) => Future.value([]),
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

      expect(find.text('Neighborhood Walk'), findsOneWidget);

      // Tap the list item
      await tester.tap(find.text('Neighborhood Walk'));
      await tester.pumpAndSettle();

      // Verify RouteDetailSheet opened
      expect(find.byType(RouteDetailSheet), findsOneWidget);
      expect(find.text('Cloud Synced'), findsOneWidget);
    });
  });
}
