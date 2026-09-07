import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import '../../../core/database/database_provider.dart';
import '../../entries/providers/entries_provider.dart';
import '../models/movement_models.dart';

/// Stream provider that reactively watches total steps recorded in Drift SQLite for today.
final todayStepCountStreamProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  return db.watchEntriesForDay(now).map((entries) {
    final stepEntries = entries.where((e) => e.type == 'steps');
    if (stepEntries.isEmpty) return 0;
    return stepEntries.fold<int>(0, (sum, e) => sum + e.value.toInt());
  });
});

/// Riverpod Notifier managing real-time hardware pedometer sensor state.
class StepTrackingNotifier extends Notifier<MovementState> {
  final StepNormalizer _normalizer = StepNormalizer();
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  DateTime? _lastDbWriteTime;

  @override
  MovementState build() {
    ref.onDispose(() {
      _stepCountSubscription?.cancel();
      _pedestrianStatusSubscription?.cancel();
    });

    // Auto-initialize sensor listening after build returns
    Future.microtask(_initPedometer);

    return const MovementState();
  }

  /// Initialize hardware sensor stream subscriptions with defensive error handling.
  void _initPedometer() {
    try {
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: _onPedestrianStatusError,
      );

      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
      );

      state = state.copyWith(status: StepSensorStatus.listening);
    } catch (e) {
      state = state.copyWith(
        status: StepSensorStatus.unavailable,
        errorMessage: e.toString(),
      );
    }
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    state = state.copyWith(pedestrianStatus: event.status);
  }

  void _onPedestrianStatusError(dynamic error) {
    // Pedestrian status not supported on all devices; keep step counting alive
    state = state.copyWith(pedestrianStatus: 'unknown');
  }

  void _onStepCount(StepCount event) {
    final todaySteps = _normalizer.onStepCount(event.steps, event.timeStamp);

    state = state.copyWith(
      stepsToday: todaySteps,
      status: StepSensorStatus.listening,
    );

    // Debounce SQLite database writes to at most once every 5 seconds
    final now = DateTime.now();
    if (_lastDbWriteTime == null || now.difference(_lastDbWriteTime!) > const Duration(seconds: 5)) {
      _lastDbWriteTime = now;
      _persistStepsToDatabase(todaySteps);
    }
  }

  void _onStepCountError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      state = state.copyWith(
        status: StepSensorStatus.permissionDenied,
        errorMessage: 'Activity Recognition permission is required for step counting.',
      );
    } else {
      state = state.copyWith(
        status: StepSensorStatus.unavailable,
        errorMessage: 'Step hardware sensor is not available on this device.',
      );
    }
  }

  /// Persist the latest daily total steps into Drift SQLite entries table.
  Future<void> _persistStepsToDatabase(int steps) async {
    if (steps <= 0) return;
    try {
      final entryController = ref.read(entryControllerProvider);
      await entryController.logEntry(
        type: 'steps',
        value: steps.toDouble(),
        unit: 'steps',
        metadata: {'source': 'hardware_pedometer'},
      );
    } catch (_) {
      // Database errors should not crash the sensor stream
    }
  }

  /// Allow manual step logging (for workouts, manual entry, or testing on emulators).
  Future<void> logManualSteps(int count, {String? notes}) async {
    if (count <= 0) return;
    final newTotal = state.stepsToday + count;
    state = state.copyWith(stepsToday: newTotal);

    final entryController = ref.read(entryControllerProvider);
    await entryController.logEntry(
      type: 'steps',
      value: count.toDouble(),
      unit: 'steps',
      note: notes ?? 'Manual step entry',
      metadata: {'source': 'manual_log'},
    );
  }

  /// Set user daily step target.
  void setDailyTarget(int target) {
    if (target > 0) {
      state = state.copyWith(dailyTarget: target);
    }
  }
}

/// Provider for StepTrackingNotifier.
final stepTrackingProvider =
    NotifierProvider<StepTrackingNotifier, MovementState>(
  () => StepTrackingNotifier(),
);
