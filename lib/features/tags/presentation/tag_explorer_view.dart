import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/tagged_item.dart';
import '../providers/tag_explorer_provider.dart';

/// Unified Tag Explorer & cross-module search (Chunk 25 / Phase 4).
///
/// One search box + tag chips query `entries`, `expenses`, and
/// `study_sessions` together via their shared tag vocabulary.
class TagExplorerView extends ConsumerStatefulWidget {
  const TagExplorerView({super.key});

  @override
  ConsumerState<TagExplorerView> createState() => _TagExplorerViewState();
}

class _TagExplorerViewState extends ConsumerState<TagExplorerView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = ref.watch(allTagsProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final results = ref.watch(tagSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tag Explorer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SearchBar(
            controller: _searchController,
            hintText: 'Search everything tagged… (e.g. Thesis)',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (_searchController.text.isNotEmpty || selectedTag != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(tagQueryProvider.notifier).clear();
                    ref.read(selectedTagProvider.notifier).select(null);
                    setState(() {});
                  },
                ),
            ],
            onChanged: (v) => ref.read(tagQueryProvider.notifier).setQuery(v),
          ),
          const SizedBox(height: 12),
          if (tags.isEmpty)
            Text(
              'No tags yet — add tags to entries, expenses, or study sessions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in tags)
                  FilterChip(
                    label: Text(tag),
                    selected: selectedTag == tag,
                    onSelected: (_) =>
                        ref.read(selectedTagProvider.notifier).toggle(tag),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            '${results.length} result${results.length == 1 ? '' : 's'}',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (results.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Nothing matches. Try a different keyword or clear the tag filter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final item in results) _TaggedResultTile(item: item),
        ],
      ),
    );
  }
}

class _TaggedResultTile extends StatelessWidget {
  final TaggedItem item;

  const _TaggedResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('MMM d, hh:mm a').format(item.occurredAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_sourceIcon(item.source), color: _sourceColor(item.source)),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.subtitle != null)
              Text(item.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              '$dateLabel · ${item.source}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (item.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final t in item.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: item.tags.isNotEmpty,
      ),
    );
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'study':
        return Icons.timer_rounded;
      case 'entry':
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'expense':
        return Colors.amber.shade800;
      case 'study':
        return Colors.purple;
      case 'entry':
      default:
        return Colors.blue;
    }
  }
}
