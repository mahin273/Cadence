import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';
import '../../study/presentation/pomodoro_view.dart';
import '../../routines/presentation/routines_view.dart';
import '../../movement/presentation/movement_view.dart';

/// Proportional time block widget positioned inside the vertical planner timeline.
class TimeBlockTile extends ConsumerWidget {
  final TimeBlockWithConflict block;
  final double width;
  final VoidCallback? onTap;

  const TimeBlockTile({
    super.key,
    required this.block,
    required this.width,
    this.onTap,
  });

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    final event = block.event;
    final category = CalendarCategoryConfig.getCategory(event.category);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category & Conflict header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: category.defaultColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category.icon, size: 14, color: category.defaultColor),
                          const SizedBox(width: 4),
                          Text(
                            category.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: category.defaultColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (block.hasConflict)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'Time Conflict',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  event.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Time Interval
                Text(
                  '${timeFormat.format(event.startTime)} – ${timeFormat.format(event.endTime)} (${block.durationMinutes} mins)',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (event.description != null && event.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    event.description!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Shortcut Actions into other modules
                if (event.category == 'study' || event.category == 'work') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: category.defaultColor,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.timer_rounded),
                    label: const Text('Start Focus Session for This Block'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text(event.title)),
                            body: const PomodoroView(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ] else if (event.category == 'routine') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: category.defaultColor,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.checklist_rtl_rounded),
                    label: const Text('Open Daily Routines'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Routines')),
                            body: const RoutinesView(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ] else if (event.category == 'movement' || event.category == 'health') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: category.defaultColor,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.directions_run_rounded),
                    label: const Text('Open Movement Tracker'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Movement')),
                            body: const MovementView(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // Delete Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete Time Block'),
                  onPressed: () async {
                    await ref.read(calendarControllerProvider).deleteEvent(event.id);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = block.event;
    final category = CalendarCategoryConfig.getCategory(event.category);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('HH:mm');

    final color = category.defaultColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap != null ? onTap!() : _showDetailSheet(context, ref),
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: block.hasConflict ? Colors.amber : color.withValues(alpha: 0.7),
              width: block.hasConflict ? 2.0 : 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(category.icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (block.hasConflict) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                    ],
                  ],
                ),
                if (block.durationMinutes >= 30) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(event.startTime)}–${timeFormat.format(event.endTime)} (${block.durationMinutes}m)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
