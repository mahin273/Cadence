/// Types of domain events recorded in the timeline.
enum TimelineEventType {
  study,
  movement,
  water,
  habit,
  expense,
  routine,
  calendarEvent,
}

/// An individual timestamped event occurring on a specific day.
class DayTimelineEvent {
  final String id;
  final DateTime timestamp;
  final String title;
  final String? subtitle;
  final TimelineEventType eventType;
  final String? metricValue;
  final String? tag;
  final Map<String, dynamic>? metadata;

  const DayTimelineEvent({
    required this.id,
    required this.timestamp,
    required this.title,
    this.subtitle,
    required this.eventType,
    this.metricValue,
    this.tag,
    this.metadata,
  });
}

/// Comprehensive daily aggregation replay for a specific past date.
class DayHistorySummary {
  final DateTime date;
  final List<DayTimelineEvent> events;
  final int totalStudyMinutes;
  final double totalMovementDistanceMeters;
  final double totalWaterGlasses;
  final double totalExpenses;
  final int routinesCompletedCount;

  const DayHistorySummary({
    required this.date,
    required this.events,
    this.totalStudyMinutes = 0,
    this.totalMovementDistanceMeters = 0.0,
    this.totalWaterGlasses = 0.0,
    this.totalExpenses = 0.0,
    this.routinesCompletedCount = 0,
  });

  bool get isEmpty => events.isEmpty;
  int get totalEventCount => events.length;
}

/// A search hit across all historical database tables.
class UniversalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final TimelineEventType type;
  final DateTime occurredAt;
  final String? metricValue;
  final String? tag;

  const UniversalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.occurredAt,
    this.metricValue,
    this.tag,
  });
}
