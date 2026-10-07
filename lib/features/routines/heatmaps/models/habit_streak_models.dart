/// Daily consistency and activity frequency data for a single calendar day.
class DayConsistencyData {
  final DateTime date;
  final int count;
  final int intensityLevel; // 0 (none) to 4 (peak)
  final int routineCount;
  final int focusCount;
  final int movementCount;
  final int habitCount;

  const DayConsistencyData({
    required this.date,
    required this.count,
    required this.intensityLevel,
    this.routineCount = 0,
    this.focusCount = 0,
    this.movementCount = 0,
    this.habitCount = 0,
  });

  bool get hasActivity => count > 0;
}

/// Comprehensive streak, milestone, and consistency calculations.
class StreakStats {
  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final double consistencyRate30Days;
  final double consistencyRateYear;
  final Map<DateTime, DayConsistencyData> dailyMap;

  const StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    required this.consistencyRate30Days,
    required this.consistencyRateYear,
    required this.dailyMap,
  });

  /// Factory for empty/initial states.
  factory StreakStats.empty() {
    return const StreakStats(
      currentStreak: 0,
      longestStreak: 0,
      totalActiveDays: 0,
      consistencyRate30Days: 0.0,
      consistencyRateYear: 0.0,
      dailyMap: {},
    );
  }

  DayConsistencyData getDataFor(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return dailyMap[key] ??
        DayConsistencyData(
          date: key,
          count: 0,
          intensityLevel: 0,
        );
  }
}
