import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/features/movement/models/route_models.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteMath Calculations', () {
    test('Haversine distance returns 0 for identical points', () {
      final distance = RouteMath.haversineDistance(37.7749, -122.4194, 37.7749, -122.4194);
      expect(distance, closeTo(0.0, 0.001));
    });

    test('Haversine distance accurately computes known real-world distance', () {
      // Ferry Building (37.7955, -122.3937) to Coit Tower (37.8024, -122.4058) in SF
      // Distance is ~1.31 km
      final distance = RouteMath.haversineDistance(
        37.7955,
        -122.3937,
        37.8024,
        -122.4058,
      );
      expect(distance, greaterThan(1200));
      expect(distance, lessThan(1400));
    });

    test('formatPace formats seconds per kilometer accurately', () {
      expect(RouteMath.formatPace(300), "5'00\"/km");
      expect(RouteMath.formatPace(324), "5'24\"/km");
      expect(RouteMath.formatPace(405), "6'45\"/km");
      expect(RouteMath.formatPace(0), "--'--\"/km");
      expect(RouteMath.formatPace(-10), "--'--\"/km");
      expect(RouteMath.formatPace(double.nan), "--'--\"/km");
      expect(RouteMath.formatPace(double.infinity), "--'--\"/km");
      expect(RouteMath.formatPace(4000), "--'--\"/km"); // Exceeds 1hr/km
    });
  });

  group('Route Models & State', () {
    test('ActivityType string parsing and labels', () {
      expect(ActivityType.fromString('walk'), ActivityType.walk);
      expect(ActivityType.fromString('run'), ActivityType.run);
      expect(ActivityType.fromString('cycle'), ActivityType.cycle);
      expect(ActivityType.fromString('cycling'), ActivityType.cycle);
      expect(ActivityType.fromString('unknown'), ActivityType.walk);
    });

    test('RouteRecordingState formatted outputs', () {
      const state = RouteRecordingState(
        status: RouteRecordingStatus.recording,
        durationSeconds: 3665, // 1 hr, 1 min, 5 sec
        distanceMeters: 5450, // 5.45 km
        avgPaceSecondsPerKm: 330, // 5'30"/km
      );

      expect(state.formattedDuration, '01:01:05');
      expect(state.formattedDistance, '5.45 km');
      expect(state.formattedPace, "5'30\"/km");
      expect(state.isRecording, isTrue);
      expect(state.isActive, isTrue);
    });

    test('RouteRecordingState under 1km distance formatting', () {
      const state = RouteRecordingState(
        durationSeconds: 125,
        distanceMeters: 450,
      );

      expect(state.formattedDuration, '02:05');
      expect(state.formattedDistance, '450 m');
    });
  });

  group('Drift Routes & RoutePoints Database Operations', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Create route session and update metrics on finish', () async {
      final now = DateTime.now().toUtc();
      const routeId = 'test-route-1';

      await db.createRoute(
        RoutesCompanion.insert(
          id: routeId,
          title: const drift.Value('Morning Run'),
          activityType: const drift.Value('run'),
          status: const drift.Value('recording'),
          startTime: now,
          totalDistanceMeters: const drift.Value(0.0),
          durationSeconds: const drift.Value(0),
          avgPaceSecondsPerKm: const drift.Value(0.0),
        ),
      );

      var route = await db.getRouteById(routeId);
      expect(route, isNotNull);
      expect(route!.title, 'Morning Run');
      expect(route.status, 'recording');

      // Update route on completion
      final finishTime = now.add(const Duration(minutes: 30));
      await db.updateRoute(
        routeId,
        RoutesCompanion(
          status: const drift.Value('completed'),
          endTime: drift.Value(finishTime),
          totalDistanceMeters: const drift.Value(5000.0),
          durationSeconds: const drift.Value(1800),
          avgPaceSecondsPerKm: const drift.Value(360.0),
        ),
      );

      route = await db.getRouteById(routeId);
      expect(route!.status, 'completed');
      expect(route.totalDistanceMeters, 5000.0);
      expect(route.durationSeconds, 1800);
      expect(route.avgPaceSecondsPerKm, 360.0);
      expect(route.endTime, isNotNull);
    });

    test('Batch insert route breadcrumb points and query sequentially', () async {
      final now = DateTime.now().toUtc();
      const routeId = 'test-route-batch';

      await db.createRoute(
        RoutesCompanion.insert(
          id: routeId,
          title: const drift.Value('Trail Walk'),
          activityType: const drift.Value('walk'),
          status: const drift.Value('recording'),
          startTime: now,
        ),
      );

      // Create 15 points to test batch insertion
      final points = List.generate(
        15,
        (i) => RoutePointsCompanion.insert(
          routeId: routeId,
          latitude: 37.7749 + (i * 0.0001),
          longitude: -122.4194 + (i * 0.0001),
          altitude: drift.Value(15.0 + i),
          speed: const drift.Value(1.4),
          accuracy: const drift.Value(4.5),
          timestamp: now.add(Duration(seconds: i * 2)),
          pointIndex: i,
        ),
      );

      await db.insertRoutePointsBatch(points);

      final fetchedPoints = await db.getPointsForRoute(routeId);
      expect(fetchedPoints.length, 15);
      expect(fetchedPoints.first.pointIndex, 0);
      expect(fetchedPoints.last.pointIndex, 14);
      expect(fetchedPoints[5].altitude, 20.0);
    });

    test('Deleting route cascades to delete all associated route points', () async {
      final now = DateTime.now().toUtc();
      const routeId = 'test-route-cascade';

      await db.createRoute(
        RoutesCompanion.insert(
          id: routeId,
          title: const drift.Value('To Be Deleted'),
          activityType: const drift.Value('walk'),
          status: const drift.Value('recording'),
          startTime: now,
        ),
      );

      final points = List.generate(
        5,
        (i) => RoutePointsCompanion.insert(
          routeId: routeId,
          latitude: 37.77 + i,
          longitude: -122.41 + i,
          timestamp: now,
          pointIndex: i,
        ),
      );

      await db.insertRoutePointsBatch(points);
      expect((await db.getPointsForRoute(routeId)).length, 5);

      // Delete route
      await db.deleteRoute(routeId);

      expect(await db.getRouteById(routeId), isNull);
      expect((await db.getPointsForRoute(routeId)).isEmpty, isTrue);
    });

    test('watchCompletedRoutes only streams routes with status completed', () async {
      final now = DateTime.now().toUtc();

      await db.createRoute(
        RoutesCompanion.insert(
          id: 'route-active',
          title: const drift.Value('Active'),
          status: const drift.Value('recording'),
          startTime: now,
        ),
      );

      await db.createRoute(
        RoutesCompanion.insert(
          id: 'route-done',
          title: const drift.Value('Finished'),
          status: const drift.Value('completed'),
          startTime: now.subtract(const Duration(hours: 1)),
        ),
      );

      final completed = await db.watchCompletedRoutes().first;
      expect(completed.length, 1);
      expect(completed.first.id, 'route-done');
    });
  });
}
