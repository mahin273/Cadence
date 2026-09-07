import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/screen_time_models.dart';
import '../providers/screen_time_provider.dart';

class ScreenTimeView extends ConsumerWidget {
  const ScreenTimeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedScreenTimeDateProvider);
    final summaryAsync = ref.watch(screenTimeSummaryProvider);
    final permissionAsync = ref.watch(screenTimePermissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Device Usage',
            onPressed: () {
              ref
                  .read(screenTimeControllerProvider.notifier)
                  .syncScreenTime(selectedDate);
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Date Selector Bar
          SliverToBoxAdapter(
            child: _DateSelectorBar(selectedDate: selectedDate),
          ),

          // 2. Permission Banner (if Android permission missing)
          permissionAsync.when(
            data: (hasPermission) {
              if (hasPermission) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    color: Colors.amber.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.amber),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.security_update_warning_rounded,
                              color: Colors.amber),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Usage Access permission is required to read app screen time.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(screenTimeControllerProvider.notifier)
                                  .requestPermission();
                            },
                            child: const Text('Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // 3. Hero Summary & Category Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: summaryAsync.when(
                data: (summary) => _buildHeroCard(context, summary),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text('Error loading screen time: $err'),
              ),
            ),
          ),

          // 4. Section Title: Top Applications
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Top Applications',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 5. Per-App Usage List
          summaryAsync.when(
            data: (summary) {
              if (summary.apps.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices_other_rounded,
                          size: 64,
                          color: theme.colorScheme.outline.withAlpha(128),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No screen time recorded for this date',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            ref
                                .read(screenTimeControllerProvider.notifier)
                                .syncScreenTime(selectedDate);
                          },
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sync Device Screen Time'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final maxMinutes = summary.apps.first.durationMinutes;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final app = summary.apps[index];
                      final relativeRatio = maxMinutes > 0
                          ? (app.durationMinutes / maxMinutes).clamp(0.0, 1.0)
                          : 0.0;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withAlpha(80),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: app.category.color.withAlpha(40),
                                child: Icon(
                                  app.category.icon,
                                  size: 18,
                                  color: app.category.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.appName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: relativeRatio,
                                        minHeight: 4,
                                        backgroundColor: theme
                                            .colorScheme.surfaceContainerHighest,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          app.category.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    app.formattedDuration,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    app.category.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: app.category.color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: summary.apps.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading usage list: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ScreenTimeSummary summary) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Total Screen Time',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary.formattedTotal,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (summary.totalMinutes > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(summary.topCategory.icon,
                      size: 14, color: summary.topCategory.color),
                  const SizedBox(width: 4),
                  Text(
                    'Most used: ${summary.topCategory.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: summary.topCategory.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Category Distribution Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: AppCategory.values.map((cat) {
                      final ratio = summary.categoryPercentage(cat);
                      if (ratio <= 0) return const SizedBox.shrink();
                      return Expanded(
                        flex: (ratio * 1000).toInt(),
                        child: Container(color: cat.color),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Category Legend Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: AppCategory.values.map((cat) {
                  final mins = summary.categoryMinutes[cat] ?? 0;
                  if (mins == 0) return const SizedBox.shrink();
                  final hours = mins ~/ 60;
                  final remMins = mins % 60;
                  final durationStr = hours > 0 ? '${hours}h ${remMins}m' : '${remMins}m';

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cat.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cat.color.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 12, color: cat.color),
                        const SizedBox(width: 4),
                        Text(
                          '${cat.label}: $durationStr',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateSelectorBar extends ConsumerWidget {
  final DateTime selectedDate;

  const _DateSelectorBar({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.isAtSameMomentAs(today);

    final dateLabel = isToday
        ? 'Today, ${DateFormat.MMMd().format(selectedDate)}'
        : DateFormat.yMMMd().format(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              ref.read(selectedScreenTimeDateProvider.notifier).previousDay();
            },
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: today,
              );
              if (picked != null) {
                ref
                    .read(selectedScreenTimeDateProvider.notifier)
                    .setDate(picked);
              }
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(
              dateLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isToday
                ? null
                : () {
                    ref.read(selectedScreenTimeDateProvider.notifier).nextDay();
                  },
          ),
        ],
      ),
    );
  }
}
