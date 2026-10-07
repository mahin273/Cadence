import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../models/circadian_nudge_models.dart';
import '../services/circadian_notification_service.dart';

/// Provider for the circadian notification engine.
final circadianNotificationServiceProvider =
    Provider<CircadianNotificationService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CircadianNotificationService(db: db);
});

/// Notifier managing user notification preferences.
class NotificationPreferencesNotifier extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    return const NotificationPreferences();
  }

  void toggleMaster(bool val) {
    state = state.copyWith(masterEnabled: val);
  }

  void togglePacedHydration(bool val) {
    state = state.copyWith(pacedHydrationEnabled: val);
  }

  void toggleCircadianTransitions(bool val) {
    state = state.copyWith(circadianTransitionsEnabled: val);
  }

  void toggleFocusRecovery(bool val) {
    state = state.copyWith(focusRecoveryEnabled: val);
  }

  void setDailyWaterTarget(int glasses) {
    state = state.copyWith(dailyWaterTargetGlasses: glasses.clamp(1, 24));
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);
