import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import 'geo_serializer.dart';

/// Result status of a route cloud sync operation.
enum RouteSyncStatus {
  success,
  offlineOrNoClient,
  routeNotFound,
  error,
}

/// Service handling PostGIS geometry serialization and Supabase cloud synchronization for routes.
class RouteSyncService {
  final AppDatabase db;
  final SupabaseClient? client;

  RouteSyncService({
    required this.db,
    this.client,
  });

  /// Map local Drift Route and points into a PostGIS/GeoJSON-compatible Supabase payload.
  Map<String, dynamic> routeToRemoteJson(
    Route route,
    List<RoutePoint> points, {
    String? userId,
  }) {
    final geoJson = GeoSerializer.toGeoJsonGeometry(points);

    return {
      'id': route.id,
      'user_id': ?userId,
      'title': route.title,
      'activity_type': route.activityType,
      'status': route.status,
      'start_time': route.startTime.toUtc().toIso8601String(),
      'end_time': route.endTime?.toUtc().toIso8601String(),
      'total_distance_meters': route.totalDistanceMeters,
      'duration_seconds': route.durationSeconds,
      'avg_pace_seconds_per_km': route.avgPaceSecondsPerKm,
      'geometry': geoJson,
      'updated_at': route.updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Sync a specific completed route and its breadcrumbs to Supabase PostgreSQL.
  Future<RouteSyncStatus> syncRoute(String routeId, {String? userId}) async {
    final route = await db.getRouteById(routeId);
    if (route == null) {
      return RouteSyncStatus.routeNotFound;
    }

    if (client == null) {
      return RouteSyncStatus.offlineOrNoClient;
    }

    try {
      final points = await db.getPointsForRoute(routeId);
      final activeUserId = userId ?? client?.auth.currentUser?.id;

      final payload = routeToRemoteJson(route, points, userId: activeUserId);
      await client!.from('routes').upsert(payload);

      // Mark locally as synced
      await db.updateRoute(
        routeId,
        const RoutesCompanion(
          isSynced: drift.Value(true),
        ),
      );

      return RouteSyncStatus.success;
    } catch (e) {
      return RouteSyncStatus.error;
    }
  }

  /// Push all unsynced completed routes to Supabase.
  Future<int> syncAllUnsyncedRoutes({String? userId}) async {
    if (client == null) return 0;

    final routes = await db.watchCompletedRoutes(limit: 100).first;
    final unsynced = routes.where((r) => !r.isSynced).toList();

    int successCount = 0;
    for (final r in unsynced) {
      final res = await syncRoute(r.id, userId: userId);
      if (res == RouteSyncStatus.success) {
        successCount++;
      }
    }
    return successCount;
  }
}

/// Main Riverpod provider for RouteSyncService.
final routeSyncServiceProvider = Provider<RouteSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final client = ref.watch(supabaseClientProvider);
  return RouteSyncService(db: db, client: client);
});
