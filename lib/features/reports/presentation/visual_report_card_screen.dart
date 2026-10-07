import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/report_card_models.dart';
import '../providers/report_card_providers.dart';

/// Screen presenting the Visual Report Card, consistency grade, highlights,
/// and domain-specific CSV exports.
class VisualReportCardScreen extends ConsumerWidget {
  const VisualReportCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedRange = ref.watch(reportCardTimeRangeProvider);
    final reportAsync = ref.watch(reportCardDataProvider);
    final service = ref.watch(reportCardServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Report Card & Export'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Range Selector (Week vs Month)
          SegmentedButton<ReportCardTimeRange>(
            segments: const [
              ButtonSegment(
                value: ReportCardTimeRange.week,
                label: Text('Weekly Review (7d)'),
                icon: Icon(Icons.date_range_rounded),
              ),
              ButtonSegment(
                value: ReportCardTimeRange.month,
                label: Text('Monthly Review (30d)'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
            ],
            selected: {selectedRange},
            onSelectionChanged: (newSelection) {
              ref
                  .read(reportCardTimeRangeProvider.notifier)
                  .setRange(newSelection.first);
            },
          ),

          const SizedBox(height: 16),

          // Visual Report Card
          reportAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to compile report card: $err',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            data: (report) => _buildReportCard(context, report, colorScheme, theme),
          ),

          const SizedBox(height: 24),

          // Export & Share Actions Section
          Text(
            'SHARE & EXPORT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          reportAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
            data: (report) => Column(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Report Summary'),
                  onPressed: () {
                    final text = service.formatShareableTextReport(report);
                    service.shareTextReport(text);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Export Expenses (CSV)'),
                  onPressed: () async {
                    final csv = await service.generateExpensesCsv(
                      start: report.startDate,
                      end: report.endDate,
                    );
                    final df = DateFormat('yyyyMMdd');
                    final fname = 'cadence_expenses_${df.format(report.startDate)}_${df.format(report.endDate)}.csv';
                    await service.exportAndShareCsv(
                      filename: fname,
                      csvContent: csv,
                      subject: 'Cadence Expenses CSV Export',
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.hourglass_top_outlined, size: 18),
                  label: const Text('Export Focus Sessions (CSV)'),
                  onPressed: () async {
                    final csv = await service.generateStudyCsv(
                      start: report.startDate,
                      end: report.endDate,
                    );
                    final df = DateFormat('yyyyMMdd');
                    final fname = 'cadence_focus_${df.format(report.startDate)}_${df.format(report.endDate)}.csv';
                    await service.exportAndShareCsv(
                      filename: fname,
                      csvContent: csv,
                      subject: 'Cadence Focus Sessions CSV Export',
                    );
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Export Unified Daily Telemetry (CSV)'),
                  onPressed: () async {
                    final csv = await service.generateTelemetryCsv(
                      start: report.startDate,
                      end: report.endDate,
                    );
                    final df = DateFormat('yyyyMMdd');
                    final fname = 'cadence_telemetry_${df.format(report.startDate)}_${df.format(report.endDate)}.csv';
                    await service.exportAndShareCsv(
                      filename: fname,
                      csvContent: csv,
                      subject: 'Cadence Telemetry CSV Export',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    ReportCardData report,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final df = DateFormat('MMM d, yyyy');
    final dateSubtitle = '${df.format(report.startDate)} - ${df.format(report.endDate)}';
    final focusHours = (report.totalFocusMinutes / 60.0).toStringAsFixed(1);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(90),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Consistency Grade Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        report.consistencyGrade,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${report.consistencyPercentage}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 4-Quadrant Metric Tiles
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'DEEP WORK',
                    value: '${focusHours}h',
                    sub: '${report.completedFocusSessions} sessions',
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.deepPurple,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'MOVEMENT',
                    value: '${report.totalMovementKm} km',
                    sub: 'Outdoor mobility',
                    icon: Icons.directions_run_rounded,
                    color: Colors.green,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'ROUTINES',
                    value: '${report.completedRoutinesCount}',
                    sub: 'Checklist items',
                    icon: Icons.task_alt_rounded,
                    color: colorScheme.primary,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'EXPENSES',
                    value: '\$${report.totalExpenses.toStringAsFixed(0)}',
                    sub: '${report.totalWaterGlasses.toStringAsFixed(0)} gl water',
                    icon: Icons.attach_money_rounded,
                    color: Colors.amber.shade800,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Highlights
            Text(
              'RHYTHM HIGHLIGHTS',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            for (final h in report.highlights) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
