import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../history/presentation/day_history_screen.dart';
import '../../../../history/providers/history_providers.dart';
import '../../models/habit_streak_models.dart';

/// GitHub-style 52-week activity contribution heatmap.
class GithubStyleHeatmap extends ConsumerStatefulWidget {
  final StreakStats stats;
  final int weeksCount;

  const GithubStyleHeatmap({
    super.key,
    required this.stats,
    this.weeksCount = 52,
  });

  @override
  ConsumerState<GithubStyleHeatmap> createState() => _GithubStyleHeatmapState();
}

class _GithubStyleHeatmapState extends ConsumerState<GithubStyleHeatmap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to the far right so today's most recent activities are visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getColorForLevel(int level, ColorScheme colorScheme) {
    switch (level) {
      case 1:
        return colorScheme.primary.withAlpha(65);
      case 2:
        return colorScheme.primary.withAlpha(125);
      case 3:
        return colorScheme.primary.withAlpha(195);
      case 4:
        return colorScheme.primary;
      case 0:
      default:
        return colorScheme.surfaceContainerHighest.withAlpha(70);
    }
  }

  void _showDayDetails(BuildContext context, DayConsistencyData data) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(data.date);

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  dateStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.hasActivity
                      ? '${data.count} activities logged on this day'
                      : 'No activity recorded on this day',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (data.hasActivity) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (data.routineCount > 0)
                        _buildMetricChip(
                          icon: Icons.task_alt_rounded,
                          label: '${data.routineCount} Routines',
                          colorScheme: colorScheme,
                        ),
                      if (data.focusCount > 0)
                        _buildMetricChip(
                          icon: Icons.hourglass_top_rounded,
                          label: '${data.focusCount} Focus Blocks',
                          colorScheme: colorScheme,
                        ),
                      if (data.movementCount > 0)
                        _buildMetricChip(
                          icon: Icons.directions_run_rounded,
                          label: '${data.movementCount} Movements',
                          colorScheme: colorScheme,
                        ),
                      if (data.habitCount > 0)
                        _buildMetricChip(
                          icon: Icons.water_drop_outlined,
                          label: '${data.habitCount} Habits/Water',
                          colorScheme: colorScheme,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('View in Timeline History'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ref.read(selectedHistoryDateProvider.notifier).selectDate(data.date);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DayHistoryScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate grid alignment:
    // Today is the ending day.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate the start of the week for today (Monday = 1)
    final todayWeekday = today.weekday; // 1 = Monday, 7 = Sunday
    // The Sunday ending the current week:
    final currentWeekEnd = today.add(Duration(days: 7 - todayWeekday));
    // The start Monday of the 52 weeks window:
    final gridStartDate = currentWeekEnd.subtract(Duration(days: (widget.weeksCount * 7) - 1));

    // Construct week columns
    final List<List<DateTime>> weeks = [];
    for (int w = 0; w < widget.weeksCount; w++) {
      final List<DateTime> weekDays = [];
      final weekMonday = gridStartDate.add(Duration(days: w * 7));
      for (int d = 0; d < 7; d++) {
        weekDays.add(weekMonday.add(Duration(days: d)));
      }
      weeks.add(weekDays);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day labels column
                Padding(
                  padding: const EdgeInsets.only(top: 22.0, right: 6.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildWeekdayLabel('M', theme),
                      const SizedBox(height: 12),
                      _buildWeekdayLabel('W', theme),
                      const SizedBox(height: 12),
                      _buildWeekdayLabel('F', theme),
                    ],
                  ),
                ),

                // Heatmap Weeks Grid
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels row
                    _buildMonthHeader(weeks, theme),
                    const SizedBox(height: 4),

                    // 7 Rows of tiles
                    Row(
                      children: weeks.map((week) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            children: week.map((day) {
                              final isFuture = day.isAfter(today);
                              final data = widget.stats.getDataFor(day);
                              final tileColor = isFuture
                                  ? Colors.transparent
                                  : _getColorForLevel(data.intensityLevel, colorScheme);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1.5),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(3),
                                  onTap: isFuture
                                      ? null
                                      : () => _showDayDetails(context, data),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: tileColor,
                                      borderRadius: BorderRadius.circular(2.5),
                                      border: isFuture
                                          ? null
                                          : Border.all(
                                              color: colorScheme.outlineVariant.withAlpha(40),
                                              width: 0.5,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Legend row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            for (int i = 0; i <= 4; i++) ...[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: _getColorForLevel(i, colorScheme),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(40),
                    width: 0.5,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Text(
              'More',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdayLabel(String text, ThemeData theme) {
    return SizedBox(
      height: 12,
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMonthHeader(List<List<DateTime>> weeks, ThemeData theme) {
    final List<Widget> headers = [];
    int? lastMonth;

    for (int w = 0; w < weeks.length; w++) {
      final monday = weeks[w].first;
      if (monday.month != lastMonth) {
        lastMonth = monday.month;
        headers.add(
          SizedBox(
            width: 15.0 * 4,
            child: Text(
              DateFormat('MMM').format(monday),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }

    return SizedBox(
      height: 16,
      child: Row(
        children: headers,
      ),
    );
  }
}
