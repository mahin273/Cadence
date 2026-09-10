import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/circadian_theme.dart';
import '../providers/vitals_provider.dart';

/// Hero circadian greeting banner: dynamic greeting, formatted date,
/// and live phase pill (Chunk 24: Unified Home Dashboard).
class HeroGreetingCard extends ConsumerWidget {
  final CircadianPhase phase;
  final DateTime currentTime;

  const HeroGreetingCard({
    super.key,
    required this.phase,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final greeting = greetingForHour(currentTime.hour);
    final dateLabel = DateFormat('EEEE, MMM d').format(currentTime);

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_phaseIcon(phase), color: colorScheme.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _phaseLabel(phase),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _phaseIcon(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return Icons.wb_sunny_rounded;
      case CircadianPhase.dusk:
        return Icons.wb_twilight_rounded;
      case CircadianPhase.night:
        return Icons.nightlight_round;
      case CircadianPhase.dawn:
        return Icons.wb_sunny_outlined;
    }
  }

  String _phaseLabel(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.day:
        return 'Day Focus';
      case CircadianPhase.dusk:
        return 'Wind Down';
      case CircadianPhase.night:
        return 'Recovery';
      case CircadianPhase.dawn:
        return 'Dawn';
    }
  }
}
