/// Unified cross-module search result (Chunk 25).
///
/// `tags` on `entries`, `expenses`, and `study_sessions` share one vocabulary
/// (e.g. "Thesis"), so a tag view needs no join table — just a union filtered
/// in Dart over reactive Drift streams.
class TaggedItem {
  final String id;
  final String source; // 'entry' | 'expense' | 'study'
  final String title;
  final String? subtitle;
  final List<String> tags;
  final DateTime occurredAt;

  const TaggedItem({
    required this.id,
    required this.source,
    required this.title,
    this.subtitle,
    this.tags = const [],
    required this.occurredAt,
  });
}

/// Minimal shapes for pure, DB-free filtering (also used by unit tests).
class TaggableEntry {
  final String id;
  final String type;
  final String? note;
  final List<String> tags;
  final DateTime occurredAt;

  const TaggableEntry({
    required this.id,
    required this.type,
    this.note,
    this.tags = const [],
    required this.occurredAt,
  });
}

class TaggableExpense {
  final String id;
  final String category;
  final double amount;
  final String? note;
  final List<String> tags;
  final DateTime occurredAt;

  const TaggableExpense({
    required this.id,
    required this.category,
    required this.amount,
    this.note,
    this.tags = const [],
    required this.occurredAt,
  });
}

class TaggableSession {
  final String id;
  final String subject;
  final String? tag;
  final DateTime startedAt;

  const TaggableSession({
    required this.id,
    required this.subject,
    this.tag,
    required this.startedAt,
  });
}

/// Collect distinct tags across all three modules, sorted alphabetically.
List<String> collectAllTags(
  List<TaggableEntry> entries,
  List<TaggableExpense> expenses,
  List<TaggableSession> sessions,
) {
  final set = <String>{};
  for (final e in entries) {
    set.addAll(e.tags.where((t) => t.trim().isNotEmpty));
  }
  for (final e in expenses) {
    set.addAll(e.tags.where((t) => t.trim().isNotEmpty));
  }
  for (final s in sessions) {
    if (s.tag != null && s.tag!.trim().isNotEmpty) set.add(s.tag!.trim());
  }
  final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

/// Filter union of entries + expenses + study sessions by free-text [query]
/// and/or an exact [selectedTag]. Results sorted newest-first.
List<TaggedItem> buildTaggedResults({
  required List<TaggableEntry> entries,
  required List<TaggableExpense> expenses,
  required List<TaggableSession> sessions,
  String query = '',
  String? selectedTag,
}) {
  final q = query.trim().toLowerCase();
  final selected = selectedTag;
  final results = <TaggedItem>[];

  bool tagMatches(List<String> tags, String? single) {
    if (selected == null || selected.isEmpty) return true;
    if (tags.contains(selected)) return true;
    return single != null && single == selected;
  }

  for (final e in entries) {
    if (!tagMatches(e.tags, null)) continue;
    final haystack = '${e.type} ${e.note ?? ''} ${e.tags.join(' ')}'.toLowerCase();
    if (q.isNotEmpty && !haystack.contains(q)) continue;
    results.add(TaggedItem(
      id: e.id,
      source: 'entry',
      title: e.note?.isNotEmpty == true ? e.note! : '${e.type} log',
      subtitle: e.type,
      tags: e.tags,
      occurredAt: e.occurredAt,
    ));
  }

  for (final e in expenses) {
    if (!tagMatches(e.tags, null)) continue;
    final haystack =
        '${e.category} ${e.note ?? ''} ${e.tags.join(' ')}'.toLowerCase();
    if (q.isNotEmpty && !haystack.contains(q)) continue;
    results.add(TaggedItem(
      id: e.id,
      source: 'expense',
      title: '${e.category} · \$${e.amount.toStringAsFixed(2)}',
      subtitle: e.note,
      tags: e.tags,
      occurredAt: e.occurredAt,
    ));
  }

  for (final s in sessions) {
    final sessionTag = s.tag;
    if (!tagMatches(const [], sessionTag)) continue;
    final haystack = '${s.subject} ${sessionTag ?? ''}'.toLowerCase();
    if (q.isNotEmpty && !haystack.contains(q)) continue;
    results.add(TaggedItem(
      id: s.id,
      source: 'study',
      title: s.subject,
      subtitle: sessionTag == null ? 'study session' : 'tag: $sessionTag',
      tags: sessionTag == null ? const [] : [sessionTag],
      occurredAt: s.startedAt,
    ));
  }

  results.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return results;
}
