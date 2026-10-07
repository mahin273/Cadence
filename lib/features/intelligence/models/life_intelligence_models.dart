/// Daily aggregated metrics across all Cadence life domains.
class DailyDomainMetrics {
  final DateTime date;
  final int studyMinutes;
  final int screenTimeMinutes;
  final double waterGlasses;
  final double movementMeters;
  final double routineCompletionRate;
  final double expenseAmount;

  const DailyDomainMetrics({
    required this.date,
    this.studyMinutes = 0,
    this.screenTimeMinutes = 0,
    this.waterGlasses = 0.0,
    this.movementMeters = 0.0,
    this.routineCompletionRate = 0.0,
    this.expenseAmount = 0.0,
  });

  bool get hasAnyActivity =>
      studyMinutes > 0 ||
      screenTimeMinutes > 0 ||
      waterGlasses > 0 ||
      movementMeters > 0 ||
      routineCompletionRate > 0 ||
      expenseAmount > 0;
}

/// Category of discovered cross-domain life pattern.
enum InsightCategory {
  focusVsScreenTime,
  hydrationVsMovement,
  screenTimeVsRoutines,
  focusVsSpending,
  momentumCompound,
}

/// Discovered behavioral correlation or impact contrast.
class LifeInsight {
  final String id;
  final InsightCategory category;
  final String title;
  final String headline;
  final String description;
  final String recommendation;
  final double? correlationCoefficient;
  final double contrastPercent;
  final String highGroupLabel;
  final String highGroupMetric;
  final String lowGroupLabel;
  final String lowGroupMetric;
  final int sampleDays;
  final bool isStatisticallyMeaningful;

  const LifeInsight({
    required this.id,
    required this.category,
    required this.title,
    required this.headline,
    required this.description,
    required this.recommendation,
    this.correlationCoefficient,
    required this.contrastPercent,
    required this.highGroupLabel,
    required this.highGroupMetric,
    required this.lowGroupLabel,
    required this.lowGroupMetric,
    required this.sampleDays,
    required this.isStatisticallyMeaningful,
  });
}

/// Comprehensive intelligence synthesis report for an active time window.
class IntelligenceReport {
  final int daysAnalyzed;
  final int activeDaysCount;
  final List<DailyDomainMetrics> dailyMetrics;
  final List<LifeInsight> insights;
  final LifeInsight? strongestCorrelation;
  final double dataCompleteness;

  const IntelligenceReport({
    required this.daysAnalyzed,
    required this.activeDaysCount,
    required this.dailyMetrics,
    required this.insights,
    this.strongestCorrelation,
    required this.dataCompleteness,
  });

  bool get hasSufficientData => activeDaysCount >= 3;
}
