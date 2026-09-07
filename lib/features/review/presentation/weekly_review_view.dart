import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_summary_data.dart';
import '../providers/weekly_review_providers.dart';
import '../widgets/score_gauge.dart';
import '../widgets/weekly_domain_card.dart';

/// Full screen view presenting the cross-module weekly review and reflection journal.
class WeeklyReviewView extends ConsumerStatefulWidget {
  const WeeklyReviewView({super.key});

  @override
  ConsumerState<WeeklyReviewView> createState() => _WeeklyReviewViewState();
}

class _WeeklyReviewViewState extends ConsumerState<WeeklyReviewView> {
  final TextEditingController _reflectionController = TextEditingController();
  DateTime? _lastLoadedWeek;

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWeek = ref.watch(selectedReviewWeekProvider);
    final summaryAsync = ref.watch(weeklySummaryProvider(selectedWeek));
    final savedReviewAsync = ref.watch(savedWeeklyReviewProvider(selectedWeek));

    // Synchronize reflection controller when a saved review is loaded for this week
    savedReviewAsync.whenData((review) {
      if (_lastLoadedWeek != selectedWeek) {
        _lastLoadedWeek = selectedWeek;
        _reflectionController.text = review?.reflectionNotes ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Review'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Current Week',
            icon: const Icon(Icons.today_rounded),
            onPressed: () {
              ref.read(selectedReviewWeekProvider.notifier).resetToCurrentWeek();
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Failed to aggregate weekly data: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(weeklySummaryProvider(selectedWeek)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (summary) => _buildReviewContent(
          context,
          summary: summary,
          isSaved: savedReviewAsync.value != null,
        ),
      ),
    );
  }

  Widget _buildReviewContent(
    BuildContext context, {
    required WeeklySummaryData summary,
    required bool isSaved,
  }) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Week Navigation Bar
          _buildWeekNavigationBar(context, summary),
          const SizedBox(height: 20),

          // Central Score Gauge
          ScoreGauge(score: summary.compositeScore),
          const SizedBox(height: 28),

          // Domain Performance Breakdown
          Text(
            'Domain Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          WeeklyDomainCard(
            title: 'Focus & Deep Work',
            icon: Icons.psychology_rounded,
            accentColor: const Color(0xFF8B5CF6), // Purple
            score: summary.focusScore,
            primaryMetric: summary.formattedFocusTime,
            secondaryMetric: '${summary.focusSessionsCount} sessions • Top: ${summary.topSubject}',
            statusText: summary.focusScore >= 70 ? 'Target Met' : 'In Progress',
          ),
          const SizedBox(height: 10),

          WeeklyDomainCard(
            title: 'Movement & Health',
            icon: Icons.directions_run_rounded,
            accentColor: const Color(0xFF14B8A6), // Teal
            score: summary.movementScore,
            primaryMetric: '${summary.totalSteps} steps',
            secondaryMetric: '${summary.totalDistanceKm.toStringAsFixed(1)} km recorded routes',
            statusText: summary.movementScore >= 70 ? 'Target Met' : 'Active',
          ),
          const SizedBox(height: 10),

          WeeklyDomainCard(
            title: 'Financial Health',
            icon: Icons.account_balance_wallet_rounded,
            accentColor: const Color(0xFF10B981), // Green
            score: summary.budgetScore,
            primaryMetric: '\$${summary.totalExpenses.toStringAsFixed(2)} spent',
            secondaryMetric: '\$${summary.weeklyBudget.toStringAsFixed(2)} weekly budget cap',
            statusText: summary.totalExpenses <= summary.weeklyBudget
                ? 'Under Budget'
                : 'Over Budget',
          ),
          const SizedBox(height: 10),

          WeeklyDomainCard(
            title: 'Daily Routines',
            icon: Icons.checklist_rounded,
            accentColor: const Color(0xFFF59E0B), // Amber
            score: summary.routineScore,
            primaryMetric: '${summary.routineCompletedCount} / ${summary.routinePossibleCount} completed',
            secondaryMetric: '${summary.routinePercentage}% consistency',
            statusText: summary.routineScore >= 80 ? 'Solid Habit' : 'Building',
          ),
          const SizedBox(height: 28),

          // Reflection Journaling Section
          Text(
            'Weekly Reflection & Journal',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reflect on your wins, energy levels, and what to adjust for next week.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reflectionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What went well this week? What distracted you? Next week\'s priority...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_added_rounded),
                  label: Text(isSaved ? 'Update Review' : 'Save Review Snapshot'),
                  onPressed: () => _saveReview(summary),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Export Markdown'),
                onPressed: () => _copyMarkdown(summary),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWeekNavigationBar(BuildContext context, WeeklySummaryData summary) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous Week',
            onPressed: () {
              ref.read(selectedReviewWeekProvider.notifier).previousWeek();
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                summary.dateRangeLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next Week',
            onPressed: () {
              ref.read(selectedReviewWeekProvider.notifier).nextWeek();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveReview(WeeklySummaryData summary) async {
    final notes = _reflectionController.text;
    await ref.read(weeklyReviewControllerProvider.notifier).saveReview(
          summary: summary,
          reflectionNotes: notes,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly review snapshot saved to local database!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyMarkdown(WeeklySummaryData summary) async {
    final markdown = summary.toMarkdownReport(
      reflectionNotes: _reflectionController.text,
    );
    await Clipboard.setData(ClipboardData(text: markdown));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Markdown report copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
