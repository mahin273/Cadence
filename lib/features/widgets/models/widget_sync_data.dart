/// Snapshot data payload synced to Android Home Screen Glance widget.
class WidgetSyncData {
  final int focusMinutes;
  final int todaySteps;
  final int waterGlasses;
  final int streakDays;
  final String circadianPhase;
  final DateTime lastUpdated;

  const WidgetSyncData({
    required this.focusMinutes,
    required this.todaySteps,
    required this.waterGlasses,
    required this.streakDays,
    required this.circadianPhase,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'focus_minutes': focusMinutes,
      'today_steps': todaySteps,
      'water_glasses': waterGlasses,
      'streak_days': streakDays,
      'circadian_phase': circadianPhase,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
