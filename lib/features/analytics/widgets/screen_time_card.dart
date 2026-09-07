import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screen_time_view.dart';
import '../providers/screen_time_provider.dart';

/// Dashboard card displaying daily screen time and linking to ScreenTimeView.
class ScreenTimeCard extends ConsumerWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(screenTimeSummaryProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScreenTimeView()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            theme.colorScheme.tertiaryContainer,
                        child: Icon(
                          Icons.smartphone_rounded,
                          size: 16,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Screen Time & Wellbeing',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              summaryAsync.when(
                data: (summary) {
                  if (summary.totalMinutes == 0) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'No device usage synced today',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ref
                                .read(screenTimeControllerProvider.notifier)
                                .syncScreenTime(summary.date);
                          },
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Sync'),
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.formattedTotal,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            '${summary.apps.length} apps used today',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: summary.topCategory.color.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: summary.topCategory.color.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(summary.topCategory.icon,
                                size: 14, color: summary.topCategory.color),
                            const SizedBox(width: 6),
                            Text(
                              summary.topCategory.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: summary.topCategory.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 24,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, _) => const Text('Tap to open Screen Time'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
