/// Comprehensive application settings domain model.
class AppSettings {
  // Health and Vitals Goals
  final int stepGoal;
  final double waterGoalGlasses;
  final double sleepGoalHours;
  final double screenTimeLimitHours;

  // Focus and Pomodoro Preferences
  final int pomodoroFocusMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final bool pomodoroAutoStartBreaks;
  final int routineResetHour;

  // Movement and GPS Preferences
  final bool useMetricUnits;
  final bool highAccuracyGps;
  final bool autoPauseTracking;

  // Finance Preferences
  final String defaultCurrency;
  final double budgetAlertThreshold;

  // Cloud Sync Preferences
  final bool syncWifiOnly;

  const AppSettings({
    this.stepGoal = 10000,
    this.waterGoalGlasses = 8.0,
    this.sleepGoalHours = 8.0,
    this.screenTimeLimitHours = 4.0,
    this.pomodoroFocusMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroAutoStartBreaks = false,
    this.routineResetHour = 0,
    this.useMetricUnits = true,
    this.highAccuracyGps = true,
    this.autoPauseTracking = false,
    this.defaultCurrency = '\$',
    this.budgetAlertThreshold = 0.8,
    this.syncWifiOnly = false,
  });

  AppSettings copyWith({
    int? stepGoal,
    double? waterGoalGlasses,
    double? sleepGoalHours,
    double? screenTimeLimitHours,
    int? pomodoroFocusMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    bool? pomodoroAutoStartBreaks,
    int? routineResetHour,
    bool? useMetricUnits,
    bool? highAccuracyGps,
    bool? autoPauseTracking,
    String? defaultCurrency,
    double? budgetAlertThreshold,
    bool? syncWifiOnly,
  }) {
    return AppSettings(
      stepGoal: stepGoal ?? this.stepGoal,
      waterGoalGlasses: waterGoalGlasses ?? this.waterGoalGlasses,
      sleepGoalHours: sleepGoalHours ?? this.sleepGoalHours,
      screenTimeLimitHours: screenTimeLimitHours ?? this.screenTimeLimitHours,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroShortBreakMinutes:
          pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
      pomodoroLongBreakMinutes:
          pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroAutoStartBreaks:
          pomodoroAutoStartBreaks ?? this.pomodoroAutoStartBreaks,
      routineResetHour: routineResetHour ?? this.routineResetHour,
      useMetricUnits: useMetricUnits ?? this.useMetricUnits,
      highAccuracyGps: highAccuracyGps ?? this.highAccuracyGps,
      autoPauseTracking: autoPauseTracking ?? this.autoPauseTracking,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      budgetAlertThreshold: budgetAlertThreshold ?? this.budgetAlertThreshold,
      syncWifiOnly: syncWifiOnly ?? this.syncWifiOnly,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stepGoal': stepGoal,
      'waterGoalGlasses': waterGoalGlasses,
      'sleepGoalHours': sleepGoalHours,
      'screenTimeLimitHours': screenTimeLimitHours,
      'pomodoroFocusMinutes': pomodoroFocusMinutes,
      'pomodoroShortBreakMinutes': pomodoroShortBreakMinutes,
      'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
      'pomodoroAutoStartBreaks': pomodoroAutoStartBreaks,
      'routineResetHour': routineResetHour,
      'useMetricUnits': useMetricUnits,
      'highAccuracyGps': highAccuracyGps,
      'autoPauseTracking': autoPauseTracking,
      'defaultCurrency': defaultCurrency,
      'budgetAlertThreshold': budgetAlertThreshold,
      'syncWifiOnly': syncWifiOnly,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      stepGoal: (map['stepGoal'] as num?)?.toInt() ?? 10000,
      waterGoalGlasses: (map['waterGoalGlasses'] as num?)?.toDouble() ?? 8.0,
      sleepGoalHours: (map['sleepGoalHours'] as num?)?.toDouble() ?? 8.0,
      screenTimeLimitHours:
          (map['screenTimeLimitHours'] as num?)?.toDouble() ?? 4.0,
      pomodoroFocusMinutes: (map['pomodoroFocusMinutes'] as num?)?.toInt() ?? 25,
      pomodoroShortBreakMinutes:
          (map['pomodoroShortBreakMinutes'] as num?)?.toInt() ?? 5,
      pomodoroLongBreakMinutes:
          (map['pomodoroLongBreakMinutes'] as num?)?.toInt() ?? 15,
      pomodoroAutoStartBreaks: map['pomodoroAutoStartBreaks'] as bool? ?? false,
      routineResetHour: (map['routineResetHour'] as num?)?.toInt() ?? 0,
      useMetricUnits: map['useMetricUnits'] as bool? ?? true,
      highAccuracyGps: map['highAccuracyGps'] as bool? ?? true,
      autoPauseTracking: map['autoPauseTracking'] as bool? ?? false,
      defaultCurrency: map['defaultCurrency'] as String? ?? '\$',
      budgetAlertThreshold:
          (map['budgetAlertThreshold'] as num?)?.toDouble() ?? 0.8,
      syncWifiOnly: map['syncWifiOnly'] as bool? ?? false,
    );
  }
}
