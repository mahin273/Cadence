import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import 'biometric_service.dart';
import 'data_export_service.dart';

/// Provider for hardware biometric authentication service.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// Provider for JSON database export and restoration service.
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DataExportService(db);
});

/// Preference tracking whether biometric app lock on launch is enabled.
class AppLockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool>(
  AppLockEnabledNotifier.new,
);

/// State tracking whether the application is currently locked behind biometric barrier.
class IsAppLockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() {
    state = true;
  }

  void unlock() {
    state = false;
  }
}

final isAppLockedProvider =
    NotifierProvider<IsAppLockedNotifier, bool>(
  IsAppLockedNotifier.new,
);

/// Computes high-level database row counts across all modules.
final databaseStatisticsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  final service = ref.watch(dataExportServiceProvider);
  return service.getDatabaseStatistics();
});
