import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

/// Circadian phases of the day for grouping routines.
enum RoutinePhase {
  morning('morning', 'Morning', Icons.wb_sunny_rounded, Color(0xFFFFB74D)),
  afternoon('afternoon', 'Afternoon', Icons.wb_twilight_rounded, Color(0xFF64B5F6)),
  evening('evening', 'Evening', Icons.nightlight_round, Color(0xFF9575CD)),
  anytime('anytime', 'Anytime', Icons.schedule_rounded, Color(0xFF81C784));

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const RoutinePhase(this.id, this.label, this.icon, this.color);

  static RoutinePhase fromString(String val) {
    switch (val.toLowerCase()) {
      case 'morning':
        return RoutinePhase.morning;
      case 'afternoon':
        return RoutinePhase.afternoon;
      case 'evening':
        return RoutinePhase.evening;
      case 'anytime':
      default:
        return RoutinePhase.anytime;
    }
  }
}

/// Composite model pairing a routine template with its checklist items and completion status for a day.
class RoutineWithItems {
  final Routine routine;
  final List<RoutineItem> items;
  final Set<String> completedItemIds;

  const RoutineWithItems({
    required this.routine,
    required this.items,
    this.completedItemIds = const {},
  });

  /// Circadian phase enum representation.
  RoutinePhase get phase => RoutinePhase.fromString(routine.timeOfDay);

  /// Number of completed items today.
  int get completedCount =>
      items.where((i) => completedItemIds.contains(i.id)).length;

  /// Total count of items in this routine.
  int get totalCount => items.length;

  /// Fractional progress (0.0 to 1.0).
  double get progress =>
      totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

  /// True if all items in this routine are completed today.
  bool get isAllCompleted => totalCount > 0 && completedCount == totalCount;

  /// Estimated total duration of the routine in minutes.
  int get totalDurationMinutes =>
      items.fold(0, (sum, i) => sum + i.durationMinutes);

  /// Checks if a specific item is completed.
  bool isItemCompleted(String itemId) => completedItemIds.contains(itemId);
}
