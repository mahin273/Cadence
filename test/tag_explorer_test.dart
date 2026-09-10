import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/features/tags/models/tagged_item.dart';

void main() {
  final entries = [
    TaggableEntry(
      id: 'e1',
      type: 'journal',
      note: 'Thesis outline draft',
      tags: const ['Thesis', 'Writing'],
      occurredAt: DateTime(2026, 9, 10, 9),
    ),
    TaggableEntry(
      id: 'e2',
      type: 'water',
      note: null,
      tags: const ['Health'],
      occurredAt: DateTime(2026, 9, 9, 9),
    ),
  ];
  final expenses = [
    TaggableExpense(
      id: 'x1',
      category: 'Books',
      amount: 42.0,
      note: 'Thesis references',
      tags: const ['Thesis'],
      occurredAt: DateTime(2026, 9, 10, 12),
    ),
  ];
  final sessions = [
    TaggableSession(
      id: 's1',
      subject: 'Deep work',
      tag: 'Thesis',
      startedAt: DateTime(2026, 9, 10, 14),
    ),
    TaggableSession(
      id: 's2',
      subject: 'Gym',
      tag: 'Health',
      startedAt: DateTime(2026, 9, 8, 18),
    ),
  ];

  group('collectAllTags', () {
    test('unions tags across modules, sorted', () {
      final tags = collectAllTags(entries, expenses, sessions);
      expect(tags, ['Health', 'Thesis', 'Writing']);
    });

    test('empty inputs yield empty list', () {
      expect(collectAllTags(const [], const [], const []), isEmpty);
    });
  });

  group('buildTaggedResults', () {
    test('selectedTag filters across all three modules', () {
      final results = buildTaggedResults(
        entries: entries,
        expenses: expenses,
        sessions: sessions,
        selectedTag: 'Thesis',
      );
      expect(results.map((r) => r.id).toSet(), {'e1', 'x1', 's1'});
    });

    test('free-text query matches note/category/subject', () {
      final results = buildTaggedResults(
        entries: entries,
        expenses: expenses,
        sessions: sessions,
        query: 'gym',
      );
      expect(results.map((r) => r.id).toList(), ['s2']);
    });

    test('results sorted newest-first', () {
      final results = buildTaggedResults(
        entries: entries,
        expenses: expenses,
        sessions: sessions,
      );
      expect(results.length, 5);
      for (var i = 0; i < results.length - 1; i++) {
        expect(
          results[i].occurredAt.isAfter(results[i + 1].occurredAt) ||
              results[i].occurredAt.isAtSameMomentAs(results[i + 1].occurredAt),
          isTrue,
        );
      }
    });

    test('query + tag combine as AND', () {
      final results = buildTaggedResults(
        entries: entries,
        expenses: expenses,
        sessions: sessions,
        query: 'water',
        selectedTag: 'Thesis',
      );
      expect(results, isEmpty);
    });
  });
}
