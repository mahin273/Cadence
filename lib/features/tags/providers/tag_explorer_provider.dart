import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../study/providers/pomodoro_provider.dart';
import '../models/tagged_item.dart';

/// Free-text query for cross-module search.
class TagQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
  void clear() => state = '';
}

final tagQueryProvider = NotifierProvider<TagQueryNotifier, String>(TagQueryNotifier.new);

/// Exact tag filter chip selection (null = no tag filter).
class SelectedTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? tag) => state = tag;
  void toggle(String tag) => state = state == tag ? null : tag;
}

final selectedTagProvider = NotifierProvider<SelectedTagNotifier, String?>(SelectedTagNotifier.new);

/// Distinct tag vocabulary across entries + expenses + study sessions.
final allTagsProvider = Provider<List<String>>((ref) {
  final entries = ref.watch(entriesStreamProvider).value ?? [];
  final expenses = ref.watch(allExpensesStreamProvider).value ?? [];
  final sessions = ref.watch(recentStudySessionsStreamProvider).value ?? [];

  return collectAllTags(
    [for (final e in entries) TaggableEntry(id: e.id, type: e.type, note: e.note, tags: e.tags, occurredAt: e.occurredAt)],
    [
      for (final e in expenses)
        TaggableExpense(id: e.id, category: e.category, amount: e.amount, note: e.note, tags: e.tags, occurredAt: e.occurredAt),
    ],
    [
      for (final s in sessions)
        TaggableSession(id: s.id, subject: s.subject, tag: s.tag, startedAt: s.startedAt),
    ],
  );
});

/// Unified newest-first results across all modules.
final tagSearchResultsProvider = Provider<List<TaggedItem>>((ref) {
  final query = ref.watch(tagQueryProvider);
  final selectedTag = ref.watch(selectedTagProvider);
  final entries = ref.watch(entriesStreamProvider).value ?? [];
  final expenses = ref.watch(allExpensesStreamProvider).value ?? [];
  final sessions = ref.watch(recentStudySessionsStreamProvider).value ?? [];

  // Keep provider alive even if DB is unavailable.
  try {
    ref.watch(appDatabaseProvider);
  } catch (_) {
    return const [];
  }

  return buildTaggedResults(
    entries: [
      for (final e in entries)
        TaggableEntry(id: e.id, type: e.type, note: e.note, tags: e.tags, occurredAt: e.occurredAt),
    ],
    expenses: [
      for (final e in expenses)
        TaggableExpense(id: e.id, category: e.category, amount: e.amount, note: e.note, tags: e.tags, occurredAt: e.occurredAt),
    ],
    sessions: [
      for (final s in sessions)
        TaggableSession(id: s.id, subject: s.subject, tag: s.tag, startedAt: s.startedAt),
    ],
    query: query,
    selectedTag: selectedTag,
  );
});
