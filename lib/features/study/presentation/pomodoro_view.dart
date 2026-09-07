import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pomodoro_models.dart';
import '../providers/pomodoro_provider.dart';
import '../widgets/pomodoro_progress_dial.dart';
import '../widgets/study_history_list.dart';

/// Full screen view for focused Pomodoro and study tracking sessions.
class PomodoroView extends ConsumerStatefulWidget {
  const PomodoroView({super.key});

  @override
  ConsumerState<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends ConsumerState<PomodoroView> {
  final TextEditingController _subjectController =
      TextEditingController(text: 'Deep Work');

  final List<String> _quickSubjects = const [
    'Deep Work',
    'Thesis',
    'Algorithms',
    'Reading',
    'Writing',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  void _showCustomSubjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final textController = TextEditingController(text: _subjectController.text);
        return AlertDialog(
          title: const Text('Focus Subject'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'What are you focusing on?',
              hintText: 'e.g. Master Thesis, Linear Algebra',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _subjectController.text = text;
                  });
                  ref.read(pomodoroNotifierProvider.notifier).setSubject(text);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Set Subject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroNotifierProvider);
    final notifier = ref.read(pomodoroNotifierProvider.notifier);
    final todaySeconds = ref.watch(todayStudyWorkSecondsProvider);
    final todayMinutes = (todaySeconds / 60).round();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final phaseColor = state.sessionType.color;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Focus & Study',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Intervals without drift • Pomodoro cycle',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      // Today's Focus Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$todayMinutes min today',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preset Interval Selector Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip(
                          label: '25m Pomodoro',
                          type: PomodoroSessionType.work,
                          seconds: 25 * 60,
                          isSelected: state.sessionType == PomodoroSessionType.work &&
                              state.targetSeconds == 25 * 60,
                          onTap: () => notifier.setSessionType(
                            PomodoroSessionType.work,
                            customSeconds: 25 * 60,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          label: '50m Ultradian',
                          type: PomodoroSessionType.work,
                          seconds: 50 * 60,
                          isSelected: state.sessionType == PomodoroSessionType.work &&
                              state.targetSeconds == 50 * 60,
                          onTap: () => notifier.setSessionType(
                            PomodoroSessionType.work,
                            customSeconds: 50 * 60,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          label: '90m Deep Block',
                          type: PomodoroSessionType.work,
                          seconds: 90 * 60,
                          isSelected: state.sessionType == PomodoroSessionType.work &&
                              state.targetSeconds == 90 * 60,
                          onTap: () => notifier.setSessionType(
                            PomodoroSessionType.work,
                            customSeconds: 90 * 60,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          label: '5m Break',
                          type: PomodoroSessionType.shortBreak,
                          seconds: 5 * 60,
                          isSelected: state.sessionType == PomodoroSessionType.shortBreak,
                          onTap: () => notifier.setSessionType(
                            PomodoroSessionType.shortBreak,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPresetChip(
                          label: '15m Break',
                          type: PomodoroSessionType.longBreak,
                          seconds: 15 * 60,
                          isSelected: state.sessionType == PomodoroSessionType.longBreak,
                          onTap: () => notifier.setSessionType(
                            PomodoroSessionType.longBreak,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subject Selector & Quick Chips
                  Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(state.subject),
                        onPressed: () => _showCustomSubjectDialog(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _quickSubjects
                                .where((s) => s != state.subject)
                                .map(
                                  (sub) => Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: ChoiceChip(
                                      label: Text(sub),
                                      selected: false,
                                      onSelected: (_) {
                                        setState(() {
                                          _subjectController.text = sub;
                                        });
                                        notifier.setSubject(sub);
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Circular Progress Dial
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: PomodoroProgressDial(
                state: state,
                onCenterTap: () {
                  if (state.status == PomodoroTimerStatus.running) {
                    notifier.pauseTimer();
                  } else if (state.status == PomodoroTimerStatus.paused) {
                    notifier.resumeTimer();
                  } else {
                    notifier.startTimer();
                  }
                },
              ),
            ),
          ),

          // Main Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildControls(context, state, notifier, phaseColor),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Recent Study Sessions Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Study Sessions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Recent Sessions List
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            sliver: SliverToBoxAdapter(
              child: StudyHistoryList(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required PomodoroSessionType type,
    required int seconds,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: type.color.withValues(alpha: 0.2),
      checkmarkColor: type.color,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? type.color : null,
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    PomodoroState state,
    PomodoroNotifier notifier,
    Color phaseColor,
  ) {
    if (state.status == PomodoroTimerStatus.running) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reset Button
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset session',
            onPressed: () => notifier.resetTimer(),
          ),
          const SizedBox(width: 20),

          // Pause Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: phaseColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.pause_rounded, size: 24),
            label: const Text('Pause', style: TextStyle(fontSize: 16)),
            onPressed: () => notifier.pauseTimer(),
          ),
          const SizedBox(width: 20),

          // Skip to Next Button
          IconButton.filledTonal(
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'Skip stage',
            onPressed: () => notifier.skipToNext(),
          ),
        ],
      );
    } else if (state.status == PomodoroTimerStatus.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reset Button
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset session',
            onPressed: () => notifier.resetTimer(),
          ),
          const SizedBox(width: 20),

          // Resume Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: phaseColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('Resume', style: TextStyle(fontSize: 16)),
            onPressed: () => notifier.resumeTimer(),
          ),
          const SizedBox(width: 20),

          // Complete & Save Early
          IconButton.filledTonal(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Finish & Save',
            onPressed: () => notifier.finishCurrentSession(isCompleted: true),
          ),
        ],
      );
    } else {
      // Idle or Completed
      return Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: phaseColor,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: Icon(
            state.status == PomodoroTimerStatus.completed
                ? Icons.fast_forward_rounded
                : Icons.play_arrow_rounded,
            size: 26,
          ),
          label: Text(
            state.status == PomodoroTimerStatus.completed
                ? 'Next Phase'
                : 'Start ${state.sessionType.label}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          onPressed: () => notifier.startTimer(),
        ),
      );
    }
  }
}
