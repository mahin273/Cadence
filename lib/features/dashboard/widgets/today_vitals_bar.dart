import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/vitals_provider.dart';

/// Horizontal daily vitals glance bar: screen time, spend, focus, routines.
///
/// Composes reactive Drift streams so chips update the instant any module
/// logs data (Chunk 24). Null-safe: fresh DB renders zeros.
class TodayVitalsBar extends ConsumerWidget {
  const TodayVitalsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitals = ref.watch(todayVitalsSummaryProvider);
    final currency = NumberFormat.simpleCurrency();

    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _VitalChip(
            icon: Icons.smartphone_rounded,
            label: 'Screen',
            value: '${vitals.screenTimeMinutes}m',
            color: Colors.blue,
          ),
          _VitalChip(
            icon: Icons.payments_outlined,
            label: 'Spent',
            value: currency.format(vitals.todaySpent),
            color: Colors.amber.shade800,
          ),
          _VitalChip(
            icon: Icons.timer_outlined,
            label: 'Focus',
            value: '${vitals.focusMinutes}m',
            color: Colors.purple,
          ),
          _VitalChip(
            icon: Icons.check_circle_outline_rounded,
            label: 'Routines',
            value: vitals.routinesTotal == 0
                ? '0%'
                : '${((vitals.routinesProgress) * 100).round()}%',
            sub: '${vitals.routinesCompleted}/${vitals.routinesTotal}',
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;

  const _VitalChip({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (sub != null)
            Text(
              sub!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
