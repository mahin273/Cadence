import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/features/dashboard/providers/vitals_provider.dart';

void main() {
  group('greetingForHour', () {
    test('returns morning greeting for 5-11', () {
      expect(greetingForHour(5), 'Good Morning');
      expect(greetingForHour(11), 'Good Morning');
    });

    test('returns afternoon / evening / recovery greetings', () {
      expect(greetingForHour(12), 'Good Afternoon');
      expect(greetingForHour(17), 'Good Evening');
      expect(greetingForHour(23), 'Rest & Recovery');
      expect(greetingForHour(3), 'Rest & Recovery');
    });
  });

  group('isToday / sumSpentToday', () {
    final now = DateTime(2026, 9, 10, 15, 30);

    test('isToday matches only same calendar day', () {
      expect(isToday(DateTime(2026, 9, 10, 0, 0, 1), now), isTrue);
      expect(isToday(DateTime(2026, 9, 10, 23, 59), now), isTrue);
      expect(isToday(DateTime(2026, 9, 9, 23, 59), now), isFalse);
      expect(isToday(DateTime(2026, 9, 11, 0, 0), now), isFalse);
    });

    test('sumSpentToday ignores other days', () {
      final items = [
        (at: DateTime(2026, 9, 10, 8), amount: 5.0),
        (at: DateTime(2026, 9, 10, 20), amount: 7.5),
        (at: DateTime(2026, 9, 9, 12), amount: 100.0),
      ];
      final total = sumSpentToday(items, (e) => e.at, (e) => e.amount, now);
      expect(total, 12.5);
    });

    test('empty list sums to zero (fresh DB edge case)', () {
      expect(
        sumSpentToday(const [], (e) => e as DateTime, (e) => e as double, now),
        0.0,
      );
    });
  });

  group('DailyVitalsSummary', () {
    test('routinesProgress is 0 when no routines exist', () {
      const summary = DailyVitalsSummary();
      expect(summary.routinesProgress, 0.0);
      expect(summary.screenTimeMinutes, 0);
      expect(summary.todaySpent, 0.0);
      expect(summary.focusMinutes, 0);
    });

    test('routinesProgress computes fraction', () {
      const summary = DailyVitalsSummary(routinesCompleted: 3, routinesTotal: 4);
      expect(summary.routinesProgress, 0.75);
    });
  });
}
