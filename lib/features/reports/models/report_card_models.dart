/// Time range scope for aggregated report cards.
enum ReportCardTimeRange {
  week(7, 'Past 7 Days (Weekly Review)'),
  month(30, 'Past 30 Days (Monthly Review)');

  final int days;
  final String label;

  const ReportCardTimeRange(this.days, this.label);
}

/// Comprehensive multi-domain metrics snapshot for visual report cards.
class ReportCardData {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int totalFocusMinutes;
  final int completedFocusSessions;
  final double totalMovementKm;
  final int completedRoutinesCount;
  final double totalExpenses;
  final double totalWaterGlasses;
  final int activeDaysCount;
  final int totalDaysCount;
  final int currentStreak;
  final int longestStreak;
  final String consistencyGrade;
  final double consistencyPercentage;
  final List<String> highlights;

  const ReportCardData({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.totalFocusMinutes,
    required this.completedFocusSessions,
    required this.totalMovementKm,
    required this.completedRoutinesCount,
    required this.totalExpenses,
    required this.totalWaterGlasses,
    required this.activeDaysCount,
    required this.totalDaysCount,
    required this.currentStreak,
    required this.longestStreak,
    required this.consistencyGrade,
    required this.consistencyPercentage,
    required this.highlights,
  });
}
