/// Sensor connection lifecycle states.
enum StepSensorStatus {
  initial,
  listening,
  stopped,
  unavailable,
  permissionDenied,
}

/// Pure Dart normalizer to convert raw boot-relative hardware sensor steps into daily totals.
class StepNormalizer {
  int? todayBaseline;
  DateTime? todayDate;
  int accumulatedBeforeReboot;
  int lastRawCount;

  StepNormalizer({
    this.todayBaseline,
    this.todayDate,
    this.accumulatedBeforeReboot = 0,
    this.lastRawCount = 0,
  });

  /// Process a raw cumulative hardware step event.
  /// Returns the normalized step count for today.
  int onStepCount(int rawCount, DateTime eventTime) {
    final eventDay = DateTime(eventTime.year, eventTime.month, eventTime.day);

    // Case 1: First event or new calendar day (midnight rollover)
    if (todayDate == null || !isSameDay(eventDay, todayDate!)) {
      todayDate = eventDay;
      todayBaseline = rawCount;
      accumulatedBeforeReboot = 0;
      lastRawCount = rawCount;
      return 0;
    }

    // Case 2: Device reboot occurred during the day (hardware counter dropped to 0)
    if (rawCount < lastRawCount) {
      if (todayBaseline != null && lastRawCount >= todayBaseline!) {
        accumulatedBeforeReboot += (lastRawCount - todayBaseline!);
      }
      todayBaseline = rawCount;
    }

    lastRawCount = rawCount;

    final currentDelta = rawCount - (todayBaseline ?? rawCount);
    final totalToday = currentDelta + accumulatedBeforeReboot;
    return totalToday > 0 ? totalToday : 0;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// In-memory reactive state representing live movement telemetry.
class MovementState {
  final int stepsToday;
  final String pedestrianStatus; // 'unknown', 'walking', 'stopped'
  final StepSensorStatus status;
  final String? errorMessage;
  final int dailyTarget;

  const MovementState({
    this.stepsToday = 0,
    this.pedestrianStatus = 'unknown',
    this.status = StepSensorStatus.initial,
    this.errorMessage,
    this.dailyTarget = 10000,
  });

  /// Average stride length ~ 0.762 meters (2.5 feet).
  double get estimatedDistanceKm => (stepsToday * 0.762) / 1000.0;

  /// Average caloric burn ~ 0.04 kcal per step for an average adult.
  double get estimatedCaloriesKcal => stepsToday * 0.04;

  /// Fractional progress clamped between 0.0 and 1.0 for gauges.
  double get progressRatio =>
      (stepsToday / (dailyTarget > 0 ? dailyTarget : 10000)).clamp(0.0, 1.0);

  /// Helper flag indicating if user is actively in motion.
  bool get isWalking => pedestrianStatus.toLowerCase() == 'walking';

  MovementState copyWith({
    int? stepsToday,
    String? pedestrianStatus,
    StepSensorStatus? status,
    String? errorMessage,
    int? dailyTarget,
  }) {
    return MovementState(
      stepsToday: stepsToday ?? this.stepsToday,
      pedestrianStatus: pedestrianStatus ?? this.pedestrianStatus,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      dailyTarget: dailyTarget ?? this.dailyTarget,
    );
  }
}
