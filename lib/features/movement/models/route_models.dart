import 'dart:math' as math;

/// Activity types for GPS recorded routes.
enum ActivityType {
  walk('walk', 'Walk'),
  run('run', 'Run'),
  cycle('cycle', 'Cycle');

  final String id;
  final String label;

  const ActivityType(this.id, this.label);

  static ActivityType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'run':
        return ActivityType.run;
      case 'cycle':
      case 'cycling':
        return ActivityType.cycle;
      case 'walk':
      default:
        return ActivityType.walk;
    }
  }
}

/// Lifecycle status for live GPS route recording.
enum RouteRecordingStatus {
  idle,
  recording,
  paused,
  completed,
}

/// Lightweight geo-coordinate model decoupled from platform plugins.
class GeoCoordinate {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed; // in m/s
  final double? accuracy; // in meters
  final DateTime timestamp;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// State representation for live route recording.
class RouteRecordingState {
  final String? routeId;
  final String title;
  final ActivityType activityType;
  final RouteRecordingStatus status;
  final int durationSeconds;
  final double distanceMeters;
  final double currentPaceSecondsPerKm;
  final double avgPaceSecondsPerKm;
  final int recordedPointsCount;
  final GeoCoordinate? lastPosition;
  final String? errorMessage;

  const RouteRecordingState({
    this.routeId,
    this.title = 'Outdoor Activity',
    this.activityType = ActivityType.walk,
    this.status = RouteRecordingStatus.idle,
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.currentPaceSecondsPerKm = 0.0,
    this.avgPaceSecondsPerKm = 0.0,
    this.recordedPointsCount = 0,
    this.lastPosition,
    this.errorMessage,
  });

  bool get isRecording => status == RouteRecordingStatus.recording;
  bool get isPaused => status == RouteRecordingStatus.paused;
  bool get isActive => isRecording || isPaused;

  /// Formatted distance string (e.g., '1.24 km' or '850 m').
  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    } else {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
  }

  /// Formatted duration string (e.g. '04:12' or '01:14:32').
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Formatted pace string (e.g., "5'24\"/km").
  String get formattedPace {
    return RouteMath.formatPace(avgPaceSecondsPerKm);
  }

  /// Formatted speed in km/h.
  String get formattedSpeed {
    if (durationSeconds <= 0 || distanceMeters <= 0) return '0.0 km/h';
    final speedKmh = (distanceMeters / 1000) / (durationSeconds / 3600);
    return '${speedKmh.toStringAsFixed(1)} km/h';
  }

  RouteRecordingState copyWith({
    String? routeId,
    String? title,
    ActivityType? activityType,
    RouteRecordingStatus? status,
    int? durationSeconds,
    double? distanceMeters,
    double? currentPaceSecondsPerKm,
    double? avgPaceSecondsPerKm,
    int? recordedPointsCount,
    GeoCoordinate? lastPosition,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RouteRecordingState(
      routeId: routeId ?? this.routeId,
      title: title ?? this.title,
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentPaceSecondsPerKm: currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm ?? this.avgPaceSecondsPerKm,
      recordedPointsCount: recordedPointsCount ?? this.recordedPointsCount,
      lastPosition: lastPosition ?? this.lastPosition,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Geographic and Pace math utilities.
class RouteMath {
  static const double earthRadiusMeters = 6371000.0;

  /// Great-circle distance between two coordinates via Haversine formula (in meters).
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final lat1Rad = _degToRad(lat1);
    final lat2Rad = _degToRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1Rad) * math.cos(lat2Rad);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Convert degrees to radians.
  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Format pace in seconds per kilometer to "MM'SS\"/km".
  static String formatPace(double secondsPerKm) {
    if (secondsPerKm <= 0 || secondsPerKm.isInfinite || secondsPerKm.isNaN || secondsPerKm > 3600) {
      return "--'--\"/km";
    }

    final totalSec = secondsPerKm.round();
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;

    final sStr = seconds.toString().padLeft(2, '0');
    return "$minutes'$sStr\"/km";
  }
}
