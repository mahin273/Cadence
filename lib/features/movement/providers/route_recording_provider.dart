import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/foreground_service.dart';
import '../models/route_models.dart';

/// State notifier managing live GPS route recording, buffering, and persistence.
class RouteRecordingNotifier extends Notifier<RouteRecordingState> {
  static const int bufferThreshold = 10;
  static const double minAccuracyMeters = 25.0;
  static const double minDisplacementMeters = 2.0;

  final List<RoutePointsCompanion> _buffer = [];
  Timer? _tickerTimer;
  Timer? _flushTimer;
  StreamSubscription<Position>? _positionSubscription;
  int _pointIndex = 0;

  @override
  RouteRecordingState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const RouteRecordingState();
  }

  AppDatabase get _db => ref.read(appDatabaseProvider);

  /// Start a new outdoor route recording session.
  Future<bool> startRoute({
    String title = 'Outdoor Activity',
    ActivityType activityType = ActivityType.walk,
    Stream<Position>? mockPositionStream,
  }) async {
    if (state.isActive) return false;

    // 1. Permission and service check
    if (mockPositionStream == null) {
      final isServiceEnabled = await _checkLocationService();
      if (!isServiceEnabled) {
        state = state.copyWith(
          errorMessage: 'Location services are disabled on this device.',
        );
        return false;
      }

      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        state = state.copyWith(
          errorMessage: 'Location permission was denied.',
        );
        return false;
      }
    }

    // 2. Initialize route in DB
    final routeId = const Uuid().v4();
    final now = DateTime.now();

    try {
      await _db.createRoute(
        RoutesCompanion.insert(
          id: routeId,
          title: drift.Value(title),
          activityType: drift.Value(activityType.id),
          status: const drift.Value('recording'),
          startTime: now,
          totalDistanceMeters: const drift.Value(0.0),
          durationSeconds: const drift.Value(0),
          avgPaceSecondsPerKm: const drift.Value(0.0),
          isSynced: const drift.Value(false),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize route in database: $e');
      return false;
    }

    // 3. Reset internal counters
    _buffer.clear();
    _pointIndex = 0;

    // 4. Update state to recording
    state = RouteRecordingState(
      routeId: routeId,
      title: title,
      activityType: activityType,
      status: RouteRecordingStatus.recording,
      durationSeconds: 0,
      distanceMeters: 0.0,
      currentPaceSecondsPerKm: 0.0,
      avgPaceSecondsPerKm: 0.0,
      recordedPointsCount: 0,
      lastPosition: null,
      errorMessage: null,
    );

    // 5. Start duration ticker (1-second)
    _startDurationTicker();

    // 6. Start periodic buffer flusher (10-second)
    _startBufferFlusher();

    // 7. Subscribe to GPS position stream
    _subscribeToPositions(mockPositionStream);

    // 8. Update foreground notification if active
    _updateForegroundNotification();

    return true;
  }

  /// Pause current recording.
  Future<void> pauseRoute() async {
    if (!state.isRecording) return;

    _tickerTimer?.cancel();
    _flushTimer?.cancel();
    _positionSubscription?.pause();

    await flushBuffer();

    if (state.routeId != null) {
      await _db.updateRoute(
        state.routeId!,
        RoutesCompanion(
          status: const drift.Value('paused'),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );
    }

    state = state.copyWith(status: RouteRecordingStatus.paused);
    _updateForegroundNotification();
  }

  /// Resume paused recording.
  Future<void> resumeRoute() async {
    if (!state.isPaused) return;

    _startDurationTicker();
    _startBufferFlusher();
    _positionSubscription?.resume();

    if (state.routeId != null) {
      await _db.updateRoute(
        state.routeId!,
        RoutesCompanion(
          status: const drift.Value('recording'),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );
    }

    state = state.copyWith(status: RouteRecordingStatus.recording);
    _updateForegroundNotification();
  }

  /// Stop and finalize route recording session.
  Future<void> stopRoute() async {
    if (!state.isActive) return;

    final routeId = state.routeId;
    _tickerTimer?.cancel();
    _flushTimer?.cancel();
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // Flush any pending buffered points
    await flushBuffer();

    if (routeId != null) {
      final now = DateTime.now();
      await _db.updateRoute(
        routeId,
        RoutesCompanion(
          status: const drift.Value('completed'),
          endTime: drift.Value(now.toUtc()),
          totalDistanceMeters: drift.Value(state.distanceMeters),
          durationSeconds: drift.Value(state.durationSeconds),
          avgPaceSecondsPerKm: drift.Value(state.avgPaceSecondsPerKm),
          updatedAt: drift.Value(now.toUtc()),
        ),
      );
    }

    state = state.copyWith(
      status: RouteRecordingStatus.completed,
    );

    _updateForegroundNotification();
  }

  /// Discard/cancel active route and remove from DB.
  Future<void> cancelRoute() async {
    final routeId = state.routeId;
    _cleanup();

    if (routeId != null) {
      try {
        await _db.deleteRoute(routeId);
      } catch (_) {}
    }

    state = const RouteRecordingState();
  }

  /// Reset state to idle after viewing completed summary.
  void reset() {
    _cleanup();
    state = const RouteRecordingState();
  }

  /// Force flush any buffered breadcrumbs to SQLite.
  Future<void> flushBuffer() async {
    if (_buffer.isEmpty || state.routeId == null) return;

    final pointsToInsert = List<RoutePointsCompanion>.from(_buffer);
    _buffer.clear();

    try {
      await _db.insertRoutePointsBatch(pointsToInsert);
      await _db.updateRoute(
        state.routeId!,
        RoutesCompanion(
          totalDistanceMeters: drift.Value(state.distanceMeters),
          durationSeconds: drift.Value(state.durationSeconds),
          avgPaceSecondsPerKm: drift.Value(state.avgPaceSecondsPerKm),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );
    } catch (e) {
      // In case of error, requeue points back to buffer
      _buffer.insertAll(0, pointsToInsert);
    }
  }

  /// Process incoming location coordinate.
  void processPosition({
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    double? accuracy,
    required DateTime timestamp,
  }) {
    if (!state.isRecording || state.routeId == null) return;

    // 1. Accuracy filter
    if (accuracy != null && accuracy > minAccuracyMeters) {
      return; // Discard inaccurate reading
    }

    double deltaDistance = 0.0;
    final lastPos = state.lastPosition;

    if (lastPos != null) {
      deltaDistance = RouteMath.haversineDistance(
        lastPos.latitude,
        lastPos.longitude,
        latitude,
        longitude,
      );

      // 2. Stationary jitter filter
      if (deltaDistance < minDisplacementMeters) {
        return;
      }
    }

    final newTotalDistance = state.distanceMeters + deltaDistance;
    final newPointsCount = state.recordedPointsCount + 1;

    // 3. Compute pace (s/km)
    double avgPace = 0.0;
    if (newTotalDistance > 0 && state.durationSeconds > 0) {
      avgPace = state.durationSeconds / (newTotalDistance / 1000.0);
    }

    double currentPace = 0.0;
    if (speed != null && speed > 0.2) {
      currentPace = 1000.0 / speed;
    } else {
      currentPace = avgPace;
    }

    final newCoord = GeoCoordinate(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
      accuracy: accuracy,
      timestamp: timestamp,
    );

    // 4. Update memory buffer
    _buffer.add(
      RoutePointsCompanion.insert(
        routeId: state.routeId!,
        latitude: latitude,
        longitude: longitude,
        altitude: drift.Value(altitude),
        speed: drift.Value(speed),
        accuracy: drift.Value(accuracy),
        timestamp: timestamp,
        pointIndex: _pointIndex++,
      ),
    );

    state = state.copyWith(
      distanceMeters: newTotalDistance,
      avgPaceSecondsPerKm: avgPace,
      currentPaceSecondsPerKm: currentPace,
      recordedPointsCount: newPointsCount,
      lastPosition: newCoord,
    );

    // 5. Check if buffer reached batch limit
    if (_buffer.length >= bufferThreshold) {
      flushBuffer();
    }
  }

  void _startDurationTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRecording) return;
      final newDuration = state.durationSeconds + 1;
      double avgPace = state.avgPaceSecondsPerKm;
      if (state.distanceMeters > 0) {
        avgPace = newDuration / (state.distanceMeters / 1000.0);
      }

      state = state.copyWith(
        durationSeconds: newDuration,
        avgPaceSecondsPerKm: avgPace,
      );

      // Periodic notification update every 5 seconds
      if (newDuration % 5 == 0) {
        _updateForegroundNotification();
      }
    });
  }

  void _startBufferFlusher() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!state.isRecording) return;
      flushBuffer();
    });
  }

  void _subscribeToPositions(Stream<Position>? mockStream) {
    _positionSubscription?.cancel();

    if (mockStream != null) {
      _positionSubscription = mockStream.listen((pos) {
        processPosition(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          speed: pos.speed,
          accuracy: pos.accuracy,
          timestamp: pos.timestamp,
        );
      });
      return;
    }

    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (pos) {
          processPosition(
            latitude: pos.latitude,
            longitude: pos.longitude,
            altitude: pos.altitude,
            speed: pos.speed,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          );
        },
        onError: (err) {
          state = state.copyWith(errorMessage: 'GPS Stream error: $err');
        },
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to access GPS hardware: $e');
    }
  }

  Future<bool> _checkLocationService() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  void _updateForegroundNotification() {
    try {
      if (state.isActive) {
        CadenceForegroundService.updateService(
          title: 'Cadence • ${state.activityType.label} (${state.formattedDistance})',
          text: 'Time: ${state.formattedDuration} • Pace: ${state.formattedPace}',
        );
      }
    } catch (_) {}
  }

  void _cleanup() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _buffer.clear();
  }
}

/// Main Riverpod provider for GPS Route Recording.
final routeRecordingProvider =
    NotifierProvider<RouteRecordingNotifier, RouteRecordingState>(
  RouteRecordingNotifier.new,
);

/// Watch completed routes ordered by recency.
final completedRoutesStreamProvider = StreamProvider<List<Route>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchCompletedRoutes();
});

/// Fetch recorded points for a specific route.
final routePointsFutureProvider =
    FutureProvider.family<List<RoutePoint>, String>((ref, routeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.getPointsForRoute(routeId);
});
