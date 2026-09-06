import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../providers/entries_provider.dart';

/// Interactive activity feed showing recent entries with filtering and swipe-to-delete.
class EntriesFeed extends ConsumerWidget {
  const EntriesFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(selectedEntryTypeFilterProvider);
    final entriesAsync = ref.watch(filteredEntriesStreamProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: activeFilter == null,
                label: const Text('All Activity'),
                onSelected: (_) {
                  ref
                      .read(selectedEntryTypeFilterProvider.notifier)
                      .setFilter(null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.water_drop_outlined, size: 16),
                selected: activeFilter == 'water',
                label: const Text('Water'),
                onSelected: (selected) {
                  ref
                      .read(selectedEntryTypeFilterProvider.notifier)
                      .setFilter(selected ? 'water' : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.check_circle_outline, size: 16),
                selected: activeFilter == 'habit',
                label: const Text('Habits'),
                onSelected: (selected) {
                  ref
                      .read(selectedEntryTypeFilterProvider.notifier)
                      .setFilter(selected ? 'habit' : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.mood_outlined, size: 16),
                selected: activeFilter == 'mood',
                label: const Text('Mood'),
                onSelected: (selected) {
                  ref
                      .read(selectedEntryTypeFilterProvider.notifier)
                      .setFilter(selected ? 'mood' : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.bedtime_outlined, size: 16),
                selected: activeFilter == 'sleep',
                label: const Text('Sleep'),
                onSelected: (selected) {
                  ref
                      .read(selectedEntryTypeFilterProvider.notifier)
                      .setFilter(selected ? 'sleep' : null);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Entries List Stream
        entriesAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return Card(
                color: colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No entries recorded yet',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + Quick Log below to capture habits, hydration, mood, or sleep.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _EntryItemCard(entry: entry);
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading entries: $err',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryItemCard extends ConsumerWidget {
  final Entry entry;

  const _EntryItemCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('hh:mm a');

    final visual = _getCategoryVisual(entry.type, colorScheme);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        await ref.read(entryControllerProvider).softDelete(entry.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${entry.type} entry'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  ref.read(entryControllerProvider).restore(entry.id);
                },
              ),
            ),
          );
        }
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withAlpha(140),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tinted Category Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, color: visual.iconColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Title, Subtitle, Tags
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatEntryTitle(entry),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              entry.isSynced
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_upload_outlined,
                              size: 14,
                              color: entry.isSynced
                                  ? colorScheme.outline
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeFormat.format(entry.occurredAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: entry.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEntryTitle(Entry entry) {
    switch (entry.type) {
      case 'water':
        final val = entry.value == entry.value.roundToDouble()
            ? entry.value.toInt().toString()
            : entry.value.toString();
        return '$val ${entry.unit ?? 'glass'}';
      case 'habit':
        final habitName = entry.metadata?['habit_name'] as String?;
        return habitName ?? 'Completed Habit';
      case 'mood':
        final label = entry.metadata?['mood_label'] as String?;
        return 'Mood: ${label ?? '${entry.value.toInt()}/5'}';
      case 'sleep':
        final quality = entry.metadata?['quality'] as String?;
        return '${entry.value}h Sleep (${quality ?? 'Restful'})';
      default:
        return '${entry.type.toUpperCase()}: ${entry.value}';
    }
  }

  _CategoryVisual _getCategoryVisual(String type, ColorScheme scheme) {
    switch (type) {
      case 'water':
        return _CategoryVisual(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blueAccent,
          backgroundColor: Colors.blueAccent.withAlpha(40),
        );
      case 'habit':
        return _CategoryVisual(
          icon: Icons.check_circle_rounded,
          iconColor: Colors.teal,
          backgroundColor: Colors.teal.withAlpha(40),
        );
      case 'mood':
        return _CategoryVisual(
          icon: Icons.mood_rounded,
          iconColor: Colors.amber.shade800,
          backgroundColor: Colors.amber.withAlpha(40),
        );
      case 'sleep':
        return _CategoryVisual(
          icon: Icons.bedtime_rounded,
          iconColor: Colors.indigoAccent,
          backgroundColor: Colors.indigoAccent.withAlpha(40),
        );
      default:
        return _CategoryVisual(
          icon: Icons.analytics_outlined,
          iconColor: scheme.primary,
          backgroundColor: scheme.primaryContainer,
        );
    }
  }
}

class _CategoryVisual {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  _CategoryVisual({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}
