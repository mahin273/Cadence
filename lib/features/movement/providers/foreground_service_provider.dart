import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/foreground_service.dart';

/// Notifier managing active foreground service tracking state.
class ForegroundServiceNotifier extends Notifier<bool> {
  @override
  bool build() {
    _checkInitialState();
    return false;
  }

  Future<void> _checkInitialState() async {
    try {
      final running = await CadenceForegroundService.isRunning();
      state = running;
    } catch (_) {
      // Platform channel not available in unit test or unsupported environment
    }
  }

  /// Start persistent background tracking with sticky notification.
  Future<bool> startTracking({
    String title = 'Cadence Workout Active',
    String text = 'Tracking steps & movement...',
  }) async {
    try {
      final success = await CadenceForegroundService.startService(
        title: title,
        text: text,
      );
      if (success) {
        state = true;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Stop persistent background tracking and dismiss notification.
  Future<bool> stopTracking() async {
    try {
      final success = await CadenceForegroundService.stopService();
      if (success) {
        state = false;
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  /// Toggle tracking state.
  Future<bool> toggleTracking() async {
    if (state) {
      return !(await stopTracking());
    } else {
      return await startTracking();
    }
  }

  /// Update notification message with live metrics.
  Future<void> updateNotification({
    required int steps,
    required String cadence,
  }) async {
    if (!state) return;
    try {
      await CadenceForegroundService.updateService(
        text: '$steps steps • $cadence',
      );
    } catch (_) {
      // Ignore channel errors during background updates
    }
  }
}

/// Provider exposing the ForegroundServiceNotifier.
final foregroundServiceProvider =
    NotifierProvider<ForegroundServiceNotifier, bool>(
  () => ForegroundServiceNotifier(),
);
