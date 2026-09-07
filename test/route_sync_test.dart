import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/movement/providers/route_recording_provider.dart';
import 'package:cadence/features/movement/services/geo_serializer.dart';
import 'package:cadence/features/movement/services/route_sync_service.dart';
import 'package:cadence/features/movement/widgets/route_detail_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoSerializer Tests', () {
    test('Empty points list returns null for GeoJSON, WKT, and EWKT', () {
      expect(GeoSerializer.toGeoJsonGeometry([]), isNull);
      expect(GeoSerializer.toWktGeometry([]), isNull);
      expect(GeoSerializer.toEwktGeometry([]), isNull);
    });

    test('Single point serializes to Point geometry with Longitude first', () {
      final point = RoutePoint(
        id: 1,
        routeId: 'r1',
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        pointIndex: 0,
      );

      final geoJson = GeoSerializer.toGeoJsonGeometry([point]);
      expect(geoJson, isNotNull);
      expect(geoJson!['type'], 'Point');
      // Must be [lon, lat]
      expect(geoJson['coordinates'], [-122.4194, 37.7749]);

      final wkt = GeoSerializer.toWktGeometry([point]);
      expect(wkt, 'POINT(-122.4194 37.7749)');

      final ewkt = GeoSerializer.toEwktGeometry([point]);
      expect(ewkt, 'SRID=4326;POINT(-122.4194 37.7749)');
    });

    test('Multiple points serialize to LineString geometry with Longitude first', () {
      final points = [
        RoutePoint(
          id: 1,
          routeId: 'r2',
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: DateTime.now(),
          pointIndex: 0,
        ),
        RoutePoint(
          id: 2,
          routeId: 'r2',
          latitude: 37.7755,
          longitude: -122.4180,
          timestamp: DateTime.now(),
          pointIndex: 1,
        ),
      ];

      final geoJson = GeoSerializer.toGeoJsonGeometry(points);
      expect(geoJson, isNotNull);
      expect(geoJson!['type'], 'LineString');
      expect(geoJson['coordinates'], [
        [-122.4194, 37.7749],
        [-122.4180, 37.7755],
      ]);

      final wkt = GeoSerializer.toWktGeometry(points);
      expect(
        wkt,
        'LINESTRING(-122.4194 37.7749, -122.418 37.7755)',
      );

      final ewkt = GeoSerializer.toEwktGeometry(points, srid: 4326);
      expect(
        ewkt,
        'SRID=4326;LINESTRING(-122.4194 37.7749, -122.418 37.7755)',
      );
    });
  });

  group('RouteSyncService Unit Tests', () {
    late AppDatabase db;
    late RouteSyncService syncService;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      syncService = RouteSyncService(db: db, client: null);
    });

    tearDown(() async {
      await db.close();
    });

    test('routeToRemoteJson creates valid Supabase payload', () {
      final route = Route(
        id: 'route-json-1',
        title: 'Morning Walk',
        activityType: 'walk',
        status: 'completed',
        startTime: DateTime.utc(2026, 9, 8, 8, 0),
        endTime: DateTime.utc(2026, 9, 8, 8, 30),
        totalDistanceMeters: 2500.0,
        durationSeconds: 1800,
        avgPaceSecondsPerKm: 720.0,
        isSynced: false,
        createdAt: DateTime.utc(2026, 9, 8, 8, 0),
        updatedAt: DateTime.utc(2026, 9, 8, 8, 30),
      );

      final points = [
        RoutePoint(
          id: 1,
          routeId: 'route-json-1',
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.utc(2026, 9, 8, 8, 0),
          pointIndex: 0,
        ),
        RoutePoint(
          id: 2,
          routeId: 'route-json-1',
          latitude: 40.7135,
          longitude: -74.0050,
          timestamp: DateTime.utc(2026, 9, 8, 8, 15),
          pointIndex: 1,
        ),
      ];

      final payload = syncService.routeToRemoteJson(
        route,
        points,
        userId: 'user-xyz',
      );

      expect(payload['id'], 'route-json-1');
      expect(payload['user_id'], 'user-xyz');
      expect(payload['title'], 'Morning Walk');
      expect(payload['geometry']['type'], 'LineString');
      expect(payload['geometry']['coordinates'], [
        [-74.006, 40.7128],
        [-74.005, 40.7135],
      ]);
    });

    test('syncRoute returns routeNotFound when route does not exist in DB', () async {
      final status = await syncService.syncRoute('nonexistent-id');
      expect(status, RouteSyncStatus.routeNotFound);
    });

    test('syncRoute returns offlineOrNoClient when client is null', () async {
      await db.createRoute(
        RoutesCompanion.insert(
          id: 'local-route-1',
          title: const drift.Value('Local Run'),
          startTime: DateTime.now().toUtc(),
        ),
      );

      final status = await syncService.syncRoute('local-route-1');
      expect(status, RouteSyncStatus.offlineOrNoClient);

      // Verify route remained unsynced
      final route = await db.getRouteById('local-route-1');
      expect(route!.isSynced, isFalse);
    });
  });

  group('RouteDetailSheet Sync Interaction Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('RouteDetailSheet displays Sync to Supabase Cloud button when isSynced is false',
        (tester) async {
      final unsyncedRoute = Route(
        id: 'unsynced-route-1',
        title: 'Trail Run',
        activityType: 'run',
        status: 'completed',
        startTime: DateTime(2026, 9, 8, 7, 0),
        endTime: DateTime(2026, 9, 8, 7, 30),
        totalDistanceMeters: 3000.0,
        durationSeconds: 1800,
        avgPaceSecondsPerKm: 600.0,
        isSynced: false,
        createdAt: DateTime(2026, 9, 8, 7, 0),
        updatedAt: DateTime(2026, 9, 8, 7, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routePointsFutureProvider(unsyncedRoute.id).overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteDetailSheet(route: unsyncedRoute),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sync to Supabase Cloud'), findsOneWidget);
      expect(find.text('Local Only'), findsOneWidget);

      // Tap sync button
      await tester.tap(find.text('Sync to Supabase Cloud'));
      await tester.pumpAndSettle();

      // Expect informative SnackBar feedback (offline since client is null in test)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Sync queued (Device offline or not authenticated)'),
        findsOneWidget,
      );
    });

    testWidgets('RouteDetailSheet hides sync button when isSynced is true',
        (tester) async {
      final syncedRoute = Route(
        id: 'synced-route-1',
        title: 'Morning Walk',
        activityType: 'walk',
        status: 'completed',
        startTime: DateTime(2026, 9, 8, 7, 0),
        endTime: DateTime(2026, 9, 8, 7, 30),
        totalDistanceMeters: 2000.0,
        durationSeconds: 1200,
        avgPaceSecondsPerKm: 600.0,
        isSynced: true,
        createdAt: DateTime(2026, 9, 8, 7, 0),
        updatedAt: DateTime(2026, 9, 8, 7, 30),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            routePointsFutureProvider(syncedRoute.id).overrideWith(
              (ref) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteDetailSheet(route: syncedRoute),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cloud Synced'), findsOneWidget);
      expect(find.text('Sync to Supabase Cloud'), findsNothing);
    });
  });
}
