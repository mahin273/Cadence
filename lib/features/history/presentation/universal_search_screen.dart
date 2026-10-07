import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/day_history_models.dart';
import '../providers/history_providers.dart';

/// Universal search screen querying across all historical entries, focus blocks, expenses, and routes.
class UniversalSearchScreen extends ConsumerStatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  ConsumerState<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends ConsumerState<UniversalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeFilter = ref.watch(historySearchTypeFilterProvider);
    final resultsAsync = ref.watch(universalSearchResultsProvider);
    final dateFormatter = DateFormat('MMM d, yyyy • hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search entries, expenses, study...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(160)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(historySearchQueryProvider.notifier).clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            ref.read(historySearchQueryProvider.notifier).setQuery(val);
            setState(() {});
          },
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: activeFilter == null,
                  onSelected: (_) =>
                      ref.read(historySearchTypeFilterProvider.notifier).setFilter(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Focus'),
                  selected: activeFilter == TimelineEventType.study,
                  onSelected: (_) => ref
                      .read(historySearchTypeFilterProvider.notifier)
                      .setFilter(TimelineEventType.study),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Movement'),
                  selected: activeFilter == TimelineEventType.movement,
                  onSelected: (_) => ref
                      .read(historySearchTypeFilterProvider.notifier)
                      .setFilter(TimelineEventType.movement),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Water & Habits'),
                  selected: activeFilter == TimelineEventType.habit ||
                      activeFilter == TimelineEventType.water,
                  onSelected: (_) => ref
                      .read(historySearchTypeFilterProvider.notifier)
                      .setFilter(TimelineEventType.habit),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Expenses'),
                  selected: activeFilter == TimelineEventType.expense,
                  onSelected: (_) => ref
                      .read(historySearchTypeFilterProvider.notifier)
                      .setFilter(TimelineEventType.expense),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Results List
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Search failed: $err', style: TextStyle(color: colorScheme.error)),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Type to search your life history'
                                : 'No matching activities found',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _buildSearchResultTile(context, item, dateFormatter, colorScheme, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(
    BuildContext context,
    UniversalSearchResult item,
    DateFormat dateFormatter,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    IconData icon;
    Color iconColor;

    switch (item.type) {
      case TimelineEventType.study:
        icon = Icons.hourglass_top_rounded;
        iconColor = Colors.deepPurple;
        break;
      case TimelineEventType.movement:
        icon = Icons.directions_run_rounded;
        iconColor = Colors.green;
        break;
      case TimelineEventType.water:
        icon = Icons.water_drop_outlined;
        iconColor = Colors.blue;
        break;
      case TimelineEventType.expense:
        icon = Icons.attach_money_rounded;
        iconColor = Colors.amber.shade800;
        break;
      case TimelineEventType.habit:
      case TimelineEventType.routine:
      case TimelineEventType.calendarEvent:
        icon = Icons.check_circle_outline_rounded;
        iconColor = colorScheme.primary;
        break;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(60),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(35),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.subtitle.isNotEmpty) Text(item.subtitle),
            const SizedBox(height: 2),
            Text(
              dateFormatter.format(item.occurredAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: item.metricValue != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.metricValue!,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right, size: 18),
        onTap: () {
          // Select this date in the day history provider and return to Day History view
          ref.read(selectedHistoryDateProvider.notifier).selectDate(item.occurredAt);
          Navigator.pop(context);
        },
      ),
    );
  }
}
