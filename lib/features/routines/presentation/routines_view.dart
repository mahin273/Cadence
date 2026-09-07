import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/routines_provider.dart';
import '../widgets/create_routine_dialog.dart';
import '../widgets/routine_card.dart';

/// Comprehensive dashboard view for managing and completing daily routines.
class RoutinesView extends ConsumerWidget {
  const RoutinesView({super.key});

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const CreateRoutineDialog(),
    );
  }

  void _seedDefaultMorningRoutine(WidgetRef ref) {
    ref.read(routinesControllerProvider).createRoutine(
          title: 'Morning Launchpad',
          description: 'High-energy priming sequence before opening screens',
          timeOfDay: 'morning',
          colorValue: 0xFFFFB74D,
          itemTitles: [
            'Drink 500ml water with electrolytes',
            '5 minutes sunlight exposure & deep breathing',
            '10 minutes physical mobility & stretching',
            'Review top 3 priority tasks for today',
          ],
        );
  }

  void _seedDefaultEveningRoutine(WidgetRef ref) {
    ref.read(routinesControllerProvider).createRoutine(
          title: 'Evening Shutdown',
          description: 'Deliberate transition to restorative sleep',
          timeOfDay: 'evening',
          colorValue: 0xFF9575CD,
          itemTitles: [
            'Close all work tabs & commit open branches',
            'Tidy desk & write tomorrow\'s focus list',
            'Dim lights & disable device screens',
            '15 minutes reading fiction or journaling',
          ],
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesWithItemsStreamProvider);
    final selectedDate = ref.watch(selectedRoutineDateProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final dateDisplay = isToday
        ? 'Today, ${DateFormat('MMM d').format(selectedDate)}'
        : DateFormat('EEEE, MMM d').format(selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Header & Date Strip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
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
                            'Daily Routines',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton.outlined(
                            icon: const Icon(Icons.chevron_left_rounded, size: 20),
                            onPressed: () {
                              ref
                                  .read(selectedRoutineDateProvider.notifier)
                                  .selectDate(
                                    selectedDate.subtract(const Duration(days: 1)),
                                  );
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton.outlined(
                            icon: const Icon(Icons.today_rounded, size: 20),
                            tooltip: 'Jump to Today',
                            onPressed: () {
                              ref
                                  .read(selectedRoutineDateProvider.notifier)
                                  .resetToToday();
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton.outlined(
                            icon: const Icon(Icons.chevron_right_rounded, size: 20),
                            onPressed: () {
                              ref
                                  .read(selectedRoutineDateProvider.notifier)
                                  .selectDate(
                                    selectedDate.add(const Duration(days: 1)),
                                  );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Routines List
          routinesAsync.when(
            data: (routines) {
              if (routines.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.checklist_rtl_rounded,
                                size: 40,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Daily Routines Yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Design structured morning and evening protocols to eliminate friction and build momentum.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                                  label: const Text('+ Morning Launchpad'),
                                  onPressed: () => _seedDefaultMorningRoutine(ref),
                                ),
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.nightlight_round, size: 16),
                                  label: const Text('+ Evening Shutdown'),
                                  onPressed: () => _seedDefaultEveningRoutine(ref),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = routines[index];
                      return RoutineCard(
                        key: ValueKey(item.routine.id),
                        routineWithItems: item,
                      );
                    },
                    childCount: routines.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading routines: $err',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_create_routine',
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Routine'),
        onPressed: () => _showCreateDialog(context),
      ),
    );
  }
}
