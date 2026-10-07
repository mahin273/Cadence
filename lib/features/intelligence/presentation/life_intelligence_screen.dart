import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/life_intelligence_models.dart';
import '../providers/intelligence_providers.dart';

/// Screen presenting cross-domain behavioral correlations and life rhythm insights.
class LifeIntelligenceScreen extends ConsumerWidget {
  const LifeIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDays = ref.watch(intelligenceWindowDaysProvider);
    final reportAsync = ref.watch(lifeIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Intelligence'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Select Analysis Window',
            initialValue: selectedDays,
            onSelected: (days) {
              ref.read(intelligenceWindowDaysProvider.notifier).setDays(days);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 Days')),
              PopupMenuItem(value: 14, child: Text('Last 14 Days')),
              PopupMenuItem(value: 30, child: Text('Last 30 Days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    '$selectedDays Days',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error calculating intelligence report: $err',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ),
        data: (report) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Overview Health Header Card
              _buildOverviewCard(context, report, colorScheme, theme),
              const SizedBox(height: 16),

              // 2. Window Filter Chips
              Row(
                children: [
                  _buildWindowChip(context, ref, 7, selectedDays),
                  const SizedBox(width: 8),
                  _buildWindowChip(context, ref, 14, selectedDays),
                  const SizedBox(width: 8),
                  _buildWindowChip(context, ref, 30, selectedDays),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Discovered Insights Section
              if (report.insights.isEmpty)
                _buildSparseDataCard(context, report, colorScheme, theme)
              else ...[
                Text(
                  'Discovered Life Patterns',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...report.insights.map(
                  (insight) => _buildInsightCard(context, insight, colorScheme, theme),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWindowChip(
    BuildContext context,
    WidgetRef ref,
    int days,
    int currentDays,
  ) {
    final isSelected = days == currentDays;
    return FilterChip(
      label: Text('$days Days'),
      selected: isSelected,
      onSelected: (_) {
        ref.read(intelligenceWindowDaysProvider.notifier).setDays(days);
      },
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    IntelligenceReport report,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.psychology_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Rhythm Intelligence',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '100% on-device cross-domain behavioral correlation',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn(
                  label: 'Analyzed',
                  value: '${report.daysAnalyzed}d',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildMetricColumn(
                  label: 'Active Days',
                  value: '${report.activeDaysCount}d',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildMetricColumn(
                  label: 'Data Completeness',
                  value: '${(report.dataCompleteness * 100).toStringAsFixed(0)}%',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                _buildMetricColumn(
                  label: 'Patterns Found',
                  value: '${report.insights.length}',
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSparseDataCard(
    BuildContext context,
    IntelligenceReport report,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final needed = (3 - report.activeDaysCount).clamp(0, 3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.bubble_chart_outlined, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Gathering Behavioral Rhythm',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cadence correlates focus, screen time, hydration, movement, and expenses. Continue tracking for at least $needed more day(s) to unlock statistically verified cross-domain insights.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (report.activeDaysCount / 3).clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${report.activeDaysCount} of 3 baseline active days logged',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    LifeInsight insight,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    IconData icon;
    Color accentColor;

    switch (insight.category) {
      case InsightCategory.focusVsScreenTime:
        icon = Icons.hourglass_top_rounded;
        accentColor = Colors.deepPurple;
        break;
      case InsightCategory.hydrationVsMovement:
        icon = Icons.water_drop_outlined;
        accentColor = Colors.blue;
        break;
      case InsightCategory.screenTimeVsRoutines:
        icon = Icons.nightlife_rounded;
        accentColor = Colors.amber.shade800;
        break;
      case InsightCategory.focusVsSpending:
        icon = Icons.savings_outlined;
        accentColor = Colors.teal;
        break;
      case InsightCategory.momentumCompound:
        icon = Icons.trending_up_rounded;
        accentColor = Colors.green;
        break;
    }

    final isPositiveContrast = insight.contrastPercent > 0;
    final absContrast = insight.contrastPercent.abs().toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositiveContrast ? Colors.teal : Colors.indigo).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isPositiveContrast ? '+' : '-'}$absContrast%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isPositiveContrast ? Colors.teal : Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Headline
            Text(
              insight.headline,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              insight.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Contrast comparison pill rows
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.highGroupLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.highGroupMetric,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.lowGroupLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.lowGroupMetric,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actionable takeaway recommendation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.recommendation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
