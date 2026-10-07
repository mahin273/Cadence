/// Categories of contextual, circadian-aware notifications.
enum CircadianNudgeType {
  pacedHydration,
  circadianPhaseShift,
  focusRecovery,
  eveningShutdown,
}

/// Structured payload and metadata for an individual circadian nudge.
class CircadianNudge {
  final int id;
  final CircadianNudgeType type;
  final String title;
  final String body;
  final DateTime scheduledOrTriggeredAt;
  final Map<String, dynamic>? payload;

  const CircadianNudge({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledOrTriggeredAt,
    this.payload,
  });
}

/// User notification preferences controlling when and how context nudges trigger.
class NotificationPreferences {
  final bool masterEnabled;
  final bool pacedHydrationEnabled;
  final bool circadianTransitionsEnabled;
  final bool focusRecoveryEnabled;
  final int dailyWaterTargetGlasses;

  const NotificationPreferences({
    this.masterEnabled = true,
    this.pacedHydrationEnabled = true,
    this.circadianTransitionsEnabled = true,
    this.focusRecoveryEnabled = true,
    this.dailyWaterTargetGlasses = 8,
  });

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? pacedHydrationEnabled,
    bool? circadianTransitionsEnabled,
    bool? focusRecoveryEnabled,
    int? dailyWaterTargetGlasses,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      pacedHydrationEnabled: pacedHydrationEnabled ?? this.pacedHydrationEnabled,
      circadianTransitionsEnabled:
          circadianTransitionsEnabled ?? this.circadianTransitionsEnabled,
      focusRecoveryEnabled: focusRecoveryEnabled ?? this.focusRecoveryEnabled,
      dailyWaterTargetGlasses:
          dailyWaterTargetGlasses ?? this.dailyWaterTargetGlasses,
    );
  }
}
