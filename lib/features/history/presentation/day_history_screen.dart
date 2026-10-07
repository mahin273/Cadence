import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/day_history_models.dart';
import '../providers/history_providers.dart';
import 'universal_search_screen.dart';

/// Full Interactive Day History screen providing chronological timeline replays of any calendar date.
class DayHistoryScreen extends ConsumerWidget {
  const DayHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDate = ref.watch(selectedHistoryDateProvider);
    final historyAsync = ref.watch(dayHistoryProvider);

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    final dateTitleFormatter = DateFormat('EEEE, MMM d, yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Timeline & History'),
        actions: [
          IconButton(
            tooltip: 'Search History',
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UniversalSearchScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Pick Date',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                ref.read(selectedHistoryDateProvider.notifier).selectDate(picked);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Date Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: colorScheme.surfaceContainerHighest.withAlpha(50),
            child: Row(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_left_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(selectedHistoryDateProvider.notifier).prevDay();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        dateTitleFormatter.format(selectedDate),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isToday)
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_right_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(selectedHistoryDateProvider.notifier).nextDay();
                  },
                ),
                if (!isToday) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      ref.read(selectedHistoryDateProvider.notifier).resetToToday();
                    },
                    child: const Text('Today'),
                  ),
                ],
              ],
            ),
          ),

          // 2. Body: Summary Metrics & Timeline
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Failed to load history: $err', style: TextStyle(color: colorScheme.error)),
              ),
              data: (summary) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Daily KPI Summary Bar
                    _buildMetricsSummaryCard(context, summary, colorScheme, theme),
                    const SizedBox(height: 20),

                    // Chronological Timeline Heading
                    Row(
                      children: [
                        Text(
                          'Chronological Day Replay',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${summary.totalEventCount} items',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Empty State or Timeline items
                    if (summary.isEmpty)
                      _buildEmptyDayCard(context, colorScheme, theme)
                    else
                      ...summary.events.map(
                        (event) => _buildTimelineTile(context, event, timeFormatter, colorScheme, theme),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSummaryCard(
    BuildContext context,
    DayHistorySummary summary,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final studyMins = summary.totalStudyMinutes;
    final studyStr = studyMins >= 60
        ? '${studyMins ~/ 60}h ${studyMins % 60}m'
        : '${studyMins}m';

    final moveKm = (summary.totalMovementDistanceMeters / 1000).toStringAsFixed(1);
    final waterStr = '${summary.totalWaterGlasses.toStringAsFixed(0)} gl';
    final expStr = '\$${summary.totalExpenses.toStringAsFixed(0)}';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryColumn(
              icon: Icons.hourglass_top_rounded,
              value: studyStr,
              label: 'Study',
              color: Colors.deepPurple,
              theme: theme,
            ),
            _buildSummaryColumn(
              icon: Icons.directions_run_rounded,
              value: '${moveKm}km',
              label: 'Movement',
              color: Colors.green,
              theme: theme,
            ),
            _buildSummaryColumn(
              icon: Icons.water_drop_outlined,
              value: waterStr,
              label: 'Water',
              color: Colors.blue,
              theme: theme,
            ),
            _buildSummaryColumn(
              icon: Icons.attach_money_rounded,
              value: expStr,
              label: 'Expenses',
              color: Colors.amber.shade800,
              theme: theme,
            ),
            _buildSummaryColumn(
              icon: Icons.task_alt_rounded,
              value: '${summary.routinesCompletedCount}',
              label: 'Routines',
              color: colorScheme.primary,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTimelineTile(
    BuildContext context,
    DayTimelineEvent event,
    DateFormat timeFormatter,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    IconData icon;
    Color iconColor;

    switch (event.eventType) {
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
      case TimelineEventType.routine:
        icon = Icons.task_alt_rounded;
        iconColor = colorScheme.primary;
        break;
      case TimelineEventType.habit:
      case TimelineEventType.calendarEvent:
        icon = Icons.event_note_rounded;
        iconColor = Colors.teal;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time label on the left
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Text(
                timeFormatter.format(event.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Vertical timeline spine
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Content Card
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withAlpha(40),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (event.subtitle != null && event.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (event.metricValue != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.metricValue!,
                          style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayCard(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No Activity Logged',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no study sessions, movement routes, water logs, or expenses recorded for this date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
