import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../providers/routines_provider.dart';

/// Single interactive checklist step within a routine.
class RoutineItemTile extends ConsumerWidget {
  final String routineId;
  final RoutineItem item;
  final bool isCompleted;
  final int index;

  const RoutineItemTile({
    super.key,
    required this.routineId,
    required this.item,
    required this.isCompleted,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        ref.read(routinesControllerProvider).deleteChecklistItem(item.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: isCompleted
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isCompleted
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 2.0,
          ),
          leading: Checkbox(
            value: isCompleted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6.0),
            ),
            onChanged: (val) {
              ref
                  .read(routinesControllerProvider)
                  .toggleItem(routineId, item.id);
            },
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  '${item.durationMinutes}m',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
