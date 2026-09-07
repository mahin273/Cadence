import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pomodoro_models.dart';
import '../presentation/pomodoro_view.dart';
import '../providers/pomodoro_provider.dart';

/// Card displayed on Today's dashboard showcasing focus study time and quick start.
class FocusTimerCard extends ConsumerWidget {
  const FocusTimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroNotifierProvider);
    final todaySeconds = ref.watch(todayStudyWorkSecondsProvider);
    final todayMinutes = (todaySeconds / 60).round();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final phaseColor = state.sessionType.color;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          color: state.status == PomodoroTimerStatus.running
              ? phaseColor.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        state.sessionType.icon,
                        color: phaseColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deep Focus & Study',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          state.status == PomodoroTimerStatus.running
                              ? '${state.sessionType.label} active'
                              : '$todayMinutes mins focused today',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Open full screen timer button
                IconButton.filledTonal(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  tooltip: 'Open Focus Timer',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Focus Timer'),
                          ),
                          body: const PomodoroView(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Middle status / countdown
            if (state.status == PomodoroTimerStatus.running ||
                state.status == PomodoroTimerStatus.paused) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          state.timeFormatted,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: phaseColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (state.status == PomodoroTimerStatus.running)
                          IconButton.filledTonal(
                            icon: const Icon(Icons.pause_rounded),
                            onPressed: () => ref
                                .read(pomodoroNotifierProvider.notifier)
                                .pauseTimer(),
                          )
                        else
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: phaseColor),
                            icon: const Icon(Icons.play_arrow_rounded),
                            onPressed: () => ref
                                .read(pomodoroNotifierProvider.notifier)
                                .resumeTimer(),
                          ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          icon: const Icon(Icons.stop_rounded),
                          onPressed: () => ref
                              .read(pomodoroNotifierProvider.notifier)
                              .finishCurrentSession(isCompleted: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start 25m Focus'),
                      onPressed: () {
                        ref
                            .read(pomodoroNotifierProvider.notifier)
                            .startTimer();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Focus Timer'),
                            ),
                            body: const PomodoroView(),
                          ),
                        ),
                      );
                    },
                    child: const Text('More Presets'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
