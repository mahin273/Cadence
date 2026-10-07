import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_models.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadFromDisk();
    return const AppSettings();
  }

  Future<File?> _getSettingsFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/app_settings.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _getSettingsFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        state = AppSettings.fromMap(data);
      }
    } catch (_) {
      // Keep defaults on read failure
    }
  }

  Future<void> _saveToDisk(AppSettings settings) async {
    try {
      final file = await _getSettingsFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(settings.toMap()), flush: true);
      }
    } catch (_) {
      // Ignore disk errors in testing/headless environments
    }
  }

  void _update(AppSettings newSettings) {
    state = newSettings;
    _saveToDisk(newSettings);
  }

  void updateStepGoal(int goal) {
    _update(state.copyWith(stepGoal: goal));
  }

  void updateWaterGoal(double glasses) {
    _update(state.copyWith(waterGoalGlasses: glasses));
  }

  void updateSleepGoal(double hours) {
    _update(state.copyWith(sleepGoalHours: hours));
  }

  void updateScreenTimeLimit(double hours) {
    _update(state.copyWith(screenTimeLimitHours: hours));
  }

  void updatePomodoroSettings({
    int? focus,
    int? shortBreak,
    int? longBreak,
    bool? autoStart,
  }) {
    _update(
      state.copyWith(
        pomodoroFocusMinutes: focus,
        pomodoroShortBreakMinutes: shortBreak,
        pomodoroLongBreakMinutes: longBreak,
        pomodoroAutoStartBreaks: autoStart,
      ),
    );
  }

  void updateRoutineResetHour(int hour) {
    _update(state.copyWith(routineResetHour: hour));
  }

  void updateMeasurementUnits({required bool useMetric}) {
    _update(state.copyWith(useMetricUnits: useMetric));
  }

  void updateGpsSettings({bool? highAccuracy, bool? autoPause}) {
    _update(
      state.copyWith(
        highAccuracyGps: highAccuracy,
        autoPauseTracking: autoPause,
      ),
    );
  }

  void updateFinanceSettings({String? currency, double? threshold}) {
    _update(
      state.copyWith(
        defaultCurrency: currency,
        budgetAlertThreshold: threshold,
      ),
    );
  }

  void updateSyncSettings({required bool wifiOnly}) {
    _update(state.copyWith(syncWifiOnly: wifiOnly));
  }
}

final appSettingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
