import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine_models.dart';
import '../providers/routines_provider.dart';
import 'routine_item_tile.dart';

/// Card displaying a single routine with progress indicator and reorderable checklist items.
class RoutineCard extends ConsumerStatefulWidget {
  final RoutineWithItems routineWithItems;

  const RoutineCard({
    super.key,
    required this.routineWithItems,
  });

  @override
  ConsumerState<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends ConsumerState<RoutineCard> {
  bool _isExpanded = true;

  void _showAddItemDialog(BuildContext context) {
    final titleController = TextEditingController();
    int duration = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add Checklist Step'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Step Title',
                  hintText: 'e.g. 10 min mobility & stretch',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Time:'),
                  DropdownButton<int>(
                    value: duration,
                    items: [1, 2, 5, 10, 15, 20, 30].map((mins) {
                      return DropdownMenuItem<int>(
                        value: mins,
                        child: Text('$mins mins'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => duration = val);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  await ref
                      .read(routinesControllerProvider)
                      .addChecklistItem(
                        widget.routineWithItems.routine.id,
                        title,
                        durationMinutes: duration,
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add Step'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteRoutineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: Text(
          'Delete "${widget.routineWithItems.routine.title}" and all its checklist steps?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await ref
                  .read(routinesControllerProvider)
                  .deleteRoutine(widget.routineWithItems.routine.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.routineWithItems;
    final routine = item.routine;
    final phase = item.phase;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = phase.color;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          color: item.isAllCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: item.isAllCompleted
          ? Colors.green.withValues(alpha: 0.05)
          : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(phase.icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            routine.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.isAllCompleted) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${phase.label} • ${item.totalDurationMinutes} mins total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: item.isAllCompleted
                        ? Colors.green.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '${item.completedCount}/${item.totalCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: item.isAllCompleted
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 6.0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.isAllCompleted ? Colors.green : accentColor,
                ),
              ),
            ),

            // Expandable Checklist Steps
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              if (item.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'No checklist steps yet. Tap "+ Add Step" below.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: item.items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final list = List.of(item.items);
                    final movedItem = list.removeAt(oldIndex);
                    list.insert(newIndex, movedItem);

                    ref.read(routinesControllerProvider).reorderItems(
                          routine.id,
                          list.map((i) => i.id).toList(),
                        );
                  },
                  itemBuilder: (context, index) {
                    final step = item.items[index];
                    final isDone = item.isItemCompleted(step.id);
                    return RoutineItemTile(
                      key: ValueKey(step.id),
                      routineId: routine.id,
                      item: step,
                      isCompleted: isDone,
                      index: index,
                    );
                  },
                ),
              const SizedBox(height: 8),
              // Footer Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Step'),
                    onPressed: () => _showAddItemDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: 'Delete Routine',
                    color: colorScheme.outline,
                    onPressed: () => _showDeleteRoutineDialog(context),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
