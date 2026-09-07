import '../../../core/database/app_database.dart';

/// Represents the real-time progress and streak state of a Goal for a given day.
class GoalProgress {
  final Goal goal;
  final double currentValue;
  final double targetValue;
  final bool isHit;
  final double percentage;
  final int streakDays;

  const GoalProgress({
    required this.goal,
    required this.currentValue,
    required this.targetValue,
    required this.isHit,
    required this.percentage,
    required this.streakDays,
  });

  bool get isAtLeast => goal.targetType == 'at_least';
  bool get isAtMost => goal.targetType == 'at_most';

  String get formattedCurrent {
    if (currentValue == currentValue.roundToDouble()) {
      return currentValue.toInt().toString();
    }
    return currentValue.toStringAsFixed(1);
  }

  String get formattedTarget {
    if (targetValue == targetValue.roundToDouble()) {
      return targetValue.toInt().toString();
    }
    return targetValue.toStringAsFixed(1);
  }
}
