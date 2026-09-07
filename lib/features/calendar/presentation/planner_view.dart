import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';
import '../widgets/horizontal_date_strip.dart';
import '../widgets/calendar_event_card.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/time_blocking_timeline.dart';

/// Comprehensive Agenda Planner screen providing Day & Week schedule views.
class PlannerView extends ConsumerWidget {
  const PlannerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(calendarViewModeProvider);

    final monthYearFormatter = DateFormat('MMMM yyyy');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header Bar: Month/Year navigation, Today button, and View Mode Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
            child: Row(
              children: [
                // Navigation Prev / Next
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).prevWeek();
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).nextWeek();
                  },
                ),
                const SizedBox(width: 8),

                // Month & Year display
                Expanded(
                  child: Text(
                    monthYearFormatter.format(selectedDate),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),

                // Today jump button
                TextButton.icon(
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).jumpToToday();
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Today'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),

                // View Mode Toggle (Day vs Timeline vs Week)
                SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: CalendarViewMode.day,
                      label: Text('Day', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.timeline,
                      label: Text('Blocks', style: TextStyle(fontSize: 12)),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.week,
                      label: Text('Week', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  selected: {viewMode},
                  onSelectionChanged: (newSelection) {
                    ref
                        .read(calendarViewModeProvider.notifier)
                        .setMode(newSelection.first);
                  },
                ),
              ],
            ),
          ),

          // Horizontal Date Strip (Week view selector)
          const HorizontalDateStrip(),
          const Divider(height: 1, thickness: 1),

          // Agenda Body based on ViewMode
          Expanded(
            child: _buildBodyForViewMode(context, ref, viewMode, selectedDate),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          CreateCalendarEventDialog.show(
            context,
            initialDate: selectedDate,
          );
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Event'),
      ),
    );
  }

  Widget _buildBodyForViewMode(
    BuildContext context,
    WidgetRef ref,
    CalendarViewMode viewMode,
    DateTime selectedDate,
  ) {
    switch (viewMode) {
      case CalendarViewMode.timeline:
        return TimeBlockingTimeline(selectedDate: selectedDate);
      case CalendarViewMode.week:
        return _buildWeekAgenda(context, ref, selectedDate);
      case CalendarViewMode.day:
        return _buildDayAgenda(context, ref, selectedDate);
    }
  }

  Widget _buildDayAgenda(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final eventsAsync = ref.watch(eventsForSelectedDateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayFormatter = DateFormat('EEEE, MMMM d, yyyy');

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error loading events: $err'),
      ),
      data: (events) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 88.0),
          children: [
            // Selected Day Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dayFormatter.format(selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      '${events.length} ${events.length == 1 ? 'event' : 'events'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 48.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 56,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No events scheduled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plan your day by adding time blocks, study sessions, or appointments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        CreateCalendarEventDialog.show(
                          context,
                          initialDate: selectedDate,
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Schedule an Event'),
                    ),
                  ],
                ),
              )
            else
              ...events.map(
                (event) => CalendarEventCard(
                  event: event,
                  onEdit: () {
                    CreateCalendarEventDialog.show(
                      context,
                      existingEvent: event,
                      initialDate: selectedDate,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWeekAgenda(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final weekEventsAsync = ref.watch(eventsForWeekProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startOfWeek = getStartOfWeek(selectedDate);
    final dayTitleFormatter = DateFormat('EEEE, MMM d');

    return weekEventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error loading weekly events: $err'),
      ),
      data: (allWeekEvents) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88.0),
          itemCount: 7,
          itemBuilder: (context, index) {
            final day = startOfWeek.add(Duration(days: index));
            final dayStartUtc = DateTime(day.year, day.month, day.day, 0, 0, 0).toUtc();
            final dayEndUtc = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).toUtc();

            // Filter events that overlap with this day
            final dayEvents = allWeekEvents.where((e) {
              return (e.startTime.isBefore(dayEndUtc) || e.startTime.isAtSameMomentAs(dayEndUtc)) &&
                  (e.endTime.isAfter(dayStartUtc) || e.endTime.isAtSameMomentAs(dayStartUtc));
            }).toList();

            final isSelected = day.year == selectedDate.year &&
                day.month == selectedDate.month &&
                day.day == selectedDate.day;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Section Header
                InkWell(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).setDate(day);
                    ref
                        .read(calendarViewModeProvider.notifier)
                        .setMode(CalendarViewMode.day);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    color: isSelected
                        ? colorScheme.primaryContainer.withAlpha(50)
                        : colorScheme.surfaceContainerLowest,
                    child: Row(
                      children: [
                        Text(
                          dayTitleFormatter.format(day),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dayEvents.isEmpty
                              ? 'No events'
                              : '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),

                // Day's Event Cards
                if (dayEvents.isNotEmpty)
                  ...dayEvents.map(
                    (event) => CalendarEventCard(
                      event: event,
                      onEdit: () {
                        CreateCalendarEventDialog.show(
                          context,
                          existingEvent: event,
                          initialDate: day,
                        );
                      },
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'No events',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                const Divider(height: 1),
              ],
            );
          },
        );
      },
    );
  }
}
