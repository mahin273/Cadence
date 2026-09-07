import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';

/// Horizontal 7-day strip allowing quick date selection and indicating event density.
class HorizontalDateStrip extends ConsumerWidget {
  const HorizontalDateStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final weekEventsAsync = ref.watch(eventsForWeekProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startOfWeek = getStartOfWeek(selectedDate);
    final today = DateTime.now();

    // Map which dates in the week have events
    final weekEvents = weekEventsAsync.value ?? [];
    final daysWithEvents = <int>{};
    for (final event in weekEvents) {
      final localStart = event.startTime.toLocal();
      daysWithEvents.add(localStart.day);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = startOfWeek.add(Duration(days: index));
          final isSelected = day.year == selectedDate.year &&
              day.month == selectedDate.month &&
              day.day == selectedDate.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final hasEvents = daysWithEvents.contains(day.day);

          final weekdayName = DateFormat('E').format(day).substring(0, 3); // Mon, Tue...

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Material(
                color: isSelected
                    ? colorScheme.primary
                    : isToday
                        ? colorScheme.primaryContainer.withAlpha(80)
                        : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16.0),
                elevation: isSelected ? 2 : 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.0),
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).setDate(day);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Event presence indicator dot
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasEvents
                                ? (isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
