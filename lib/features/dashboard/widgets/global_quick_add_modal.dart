import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/widgets/create_event_dialog.dart';
import '../../entries/presentation/quick_log_modal.dart';
import '../../finance/widgets/add_expense_sheet.dart';
import '../../finance/widgets/create_debt_dialog.dart';
import '../../study/providers/pomodoro_provider.dart';

/// Lightweight definition for one quick-add tile.
class QuickAddAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const QuickAddAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// Global command-palette bottom sheet (Chunk 24).
///
/// Single high-affordance entry point offering 6 rapid cross-module actions.
/// The sheet is always dismissed first; the destination opens on the next
/// frame with the *parent* context to avoid
/// "deactivated widget ancestor" errors.
class GlobalQuickAddModal extends ConsumerWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const GlobalQuickAddModal({super.key, required this.onNavigateToTab});

  static Future<void> show(
    BuildContext context, {
    required void Function(int tabIndex) onNavigateToTab,
  }) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => GlobalQuickAddModal(onNavigateToTab: onNavigateToTab),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Add',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'What do you want to capture?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _ActionTile(
                  action: const QuickAddAction(
                    title: 'Thought / Habit',
                    subtitle: 'Log entry',
                    icon: Icons.edit_note_rounded,
                    color: Colors.blue,
                  ),
                  onTap: () => _dispatch(context, ref, () {
                    QuickLogModal.show(context);
                  }),
                ),
                _ActionTile(
                  action: QuickAddAction(
                    title: 'Log Expense',
                    subtitle: 'Record transaction',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.amber.shade800,
                  ),
                  onTap: () => _dispatch(context, ref, () {
                    AddExpenseSheet.show(context);
                  }),
                ),
                _ActionTile(
                  action: const QuickAddAction(
                    title: 'Focus Timer',
                    subtitle: 'Start 25-min block',
                    icon: Icons.timer_rounded,
                    color: Colors.purple,
                  ),
                  onTap: () => _dispatch(context, ref, () {
                    ref.read(pomodoroNotifierProvider.notifier).startTimer();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Focus session started (25 min)')),
                    );
                  }),
                ),
                _ActionTile(
                  action: const QuickAddAction(
                    title: 'Record Route',
                    subtitle: 'Track GPS walk',
                    icon: Icons.directions_run_rounded,
                    color: Colors.green,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => onNavigateToTab(2));
                  },
                ),
                _ActionTile(
                  action: const QuickAddAction(
                    title: 'Lend / Borrow',
                    subtitle: 'Record debt / IOU',
                    icon: Icons.handshake_outlined,
                    color: Colors.teal,
                  ),
                  onTap: () => _dispatch(context, ref, () {
                    CreateDebtDialog.show(context);
                  }),
                ),
                _ActionTile(
                  action: const QuickAddAction(
                    title: 'Schedule Event',
                    subtitle: 'Time-block calendar',
                    icon: Icons.event_rounded,
                    color: Colors.indigo,
                  ),
                  onTap: () => _dispatch(context, ref, () {
                    CreateCalendarEventDialog.show(context);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _dispatch(BuildContext sheetContext, WidgetRef ref, void Function() open) {
    Navigator.of(sheetContext).pop();
    Future.microtask(open);
  }
}

class _ActionTile extends StatelessWidget {
  final QuickAddAction action;
  final VoidCallback onTap;

  const _ActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(120)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    action.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    action.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
