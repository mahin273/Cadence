import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal_models.dart';
import '../providers/goals_provider.dart';
import '../../entries/providers/entries_provider.dart';

/// Interactive card displaying an individual goal, progress bar, streak count, and quick log.
class GoalCard extends ConsumerWidget {
  final GoalProgress progress;

  const GoalCard({super.key, required this.progress});

  IconData _getGoalIcon(String type) {
    switch (type.toLowerCase()) {
      case 'water':
        return Icons.water_drop_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      case 'study':
        return Icons.menu_book_rounded;
      case 'spend':
        return Icons.account_balance_wallet_rounded;
      case 'habit':
        return Icons.task_alt_rounded;
      case 'custom':
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getProgressColor(ColorScheme colorScheme) {
    if (progress.isAtMost) {
      return progress.isHit ? colorScheme.primary : colorScheme.error;
    }
    return progress.isHit ? Colors.green : colorScheme.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final goal = progress.goal;
    final progressColor = _getProgressColor(colorScheme);
    final percentInt = (progress.percentage * 100).toInt();

    return Dismissible(
      key: Key('goal_${goal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(goalsControllerProvider).softDeleteGoal(goal.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal "${goal.title}" removed'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: progress.isHit
              ? BorderSide(color: progressColor.withAlpha(120), width: 1.5)
              : BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon, Title, Streak Flame Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: progressColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getGoalIcon(goal.goalType),
                      color: progressColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          progress.isAtMost
                              ? 'Limit: max ${progress.formattedTarget} ${goal.unit ?? ''}'
                              : 'Target: min ${progress.formattedTarget} ${goal.unit ?? ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: progress.streakDays > 0
                          ? Colors.orange.withAlpha(40)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: progress.streakDays > 0
                            ? Colors.orange.withAlpha(120)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: progress.streakDays > 0
                              ? Colors.deepOrange
                              : colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${progress.streakDays}d streak',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progress.streakDays > 0
                                ? Colors.deepOrange
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.percentage.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: progressColor,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),

              // Footer Row: Achieved vs Target & Quick Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.formattedCurrent} / ${progress.formattedTarget} ${goal.unit ?? ''} ($percentInt%)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                  if (goal.goalType == 'water')
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(entryControllerProvider).logEntry(
                              type: 'water',
                              value: 1.0,
                              unit: 'glass',
                              note: 'Quick water goal log',
                            );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('+1 Glass'),
                    )
                  else if (goal.goalType == 'custom' || goal.goalType == 'habit')
                    IconButton(
                      tooltip: 'Increment +1',
                      onPressed: () async {
                        final nextVal = progress.currentValue + 1.0;
                        await ref.read(goalsControllerProvider).logManualProgress(
                              goalId: goal.id,
                              achievedValue: nextVal,
                              isHit: nextVal >= goal.targetValue,
                            );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    )
                  else if (progress.isHit)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: progressColor),
                        const SizedBox(width: 4),
                        Text(
                          'Achieved',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
