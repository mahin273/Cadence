import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../models/debt_models.dart';
import '../providers/debt_provider.dart';

class DebtLedgerView extends ConsumerWidget {
  const DebtLedgerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(debtLedgerSummaryProvider);
    final filteredDebtsAsync = ref.watch(filteredDebtsProvider);
    final tabFilter = ref.watch(debtTabFilterProvider);
    final typeFilter = ref.watch(debtTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt & Lending Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add Debt / Loan',
            onPressed: () => _showCreateDebtDialog(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Summary Cards Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: summaryAsync.when(
                data: (summary) => _buildSummaryCards(context, summary),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text('Error loading summary: $err'),
              ),
            ),
          ),

          // 2. Tab & Filter Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SegmentedButton<DebtTabFilter>(
                    segments: const [
                      ButtonSegment(
                        value: DebtTabFilter.active,
                        label: Text('Active'),
                        icon: Icon(Icons.pending_actions_rounded),
                      ),
                      ButtonSegment(
                        value: DebtTabFilter.settled,
                        label: Text('Settled'),
                        icon: Icon(Icons.task_alt_rounded),
                      ),
                    ],
                    selected: {tabFilter},
                    onSelectionChanged: (set) {
                      ref
                          .read(debtTabFilterProvider.notifier)
                          .setFilter(set.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: typeFilter == DebtTypeFilter.all,
                          onSelected: (_) => ref
                              .read(debtTypeFilterProvider.notifier)
                              .setFilter(DebtTypeFilter.all),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Owed to Me (Lent)'),
                          avatar: const Icon(Icons.call_made_rounded,
                              size: 16, color: Colors.green),
                          selected: typeFilter == DebtTypeFilter.lent,
                          onSelected: (_) => ref
                              .read(debtTypeFilterProvider.notifier)
                              .setFilter(DebtTypeFilter.lent),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('I Owe (Borrowed)'),
                          avatar: const Icon(Icons.call_received_rounded,
                              size: 16, color: Colors.redAccent),
                          selected: typeFilter == DebtTypeFilter.borrowed,
                          onSelected: (_) => ref
                              .read(debtTypeFilterProvider.notifier)
                              .setFilter(DebtTypeFilter.borrowed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 3. Debts List
          filteredDebtsAsync.when(
            data: (debts) {
              if (debts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.handshake_outlined,
                          size: 64,
                          color: theme.colorScheme.outline.withAlpha(128),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tabFilter == DebtTabFilter.active
                              ? 'No active debts found'
                              : 'No settled debts found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track peer loans and repayments cleanly',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () => _showCreateDebtDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('New Entry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final debt = debts[index];
                      return _DebtCard(debt: debt);
                    },
                    childCount: debts.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading debts: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDebtDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, DebtLedgerSummary summary) {
    final currency = NumberFormat.simpleCurrency();
    final theme = Theme.of(context);

    return Column(
      children: [
        // Net Peer Balance Banner
        Card(
          elevation: 0,
          color: summary.isPositive
              ? Colors.green.withAlpha(30)
              : Colors.redAccent.withAlpha(30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: summary.isPositive
                  ? Colors.green.withAlpha(80)
                  : Colors.redAccent.withAlpha(80),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: summary.isPositive
                      ? Colors.green.withAlpha(60)
                      : Colors.redAccent.withAlpha(60),
                  child: Icon(
                    summary.isPositive
                        ? Icons.account_balance_wallet_rounded
                        : Icons.money_off_rounded,
                    color: summary.isPositive ? Colors.green : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Peer Balance',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.netBalance >= 0 ? '+' : ''}${currency.format(summary.netBalance)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: summary.isPositive
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${summary.activeLentCount + summary.activeBorrowedCount} Active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${summary.settledCount} Settled',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Split Row: Owed to You vs You Owe
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.call_made_rounded,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            'Owed to You',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalLent),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '${summary.activeLentCount} loan${summary.activeLentCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.call_received_rounded,
                              size: 16, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text(
                            'You Owe',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currency.format(summary.totalBorrowed),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      Text(
                        '${summary.activeBorrowedCount} debt${summary.activeBorrowedCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCreateDebtDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _CreateDebtDialog(),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  final Debt debt;

  const _DebtCard({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency();
    final type = DebtType.fromId(debt.type);
    final isLent = type == DebtType.lent;
    final primaryColor = isLent ? Colors.green : Colors.redAccent;

    final paidAmount =
        (debt.initialAmount - debt.remainingAmount).clamp(0.0, double.infinity);
    final progress = debt.initialAmount > 0
        ? (paidAmount / debt.initialAmount).clamp(0.0, 1.0)
        : 0.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue =
        !debt.isSettled && debt.dueDate != null && today.isAfter(debt.dueDate!);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Avatar + Name + Type Badge + Menu
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryColor.withAlpha(40),
                  child: Text(
                    debt.personName.isNotEmpty
                        ? debt.personName.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(type.icon, size: 14, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            isLent ? 'Owed to You' : 'You Owe',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (debt.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Text('•',
                                style: TextStyle(
                                    color: theme.colorScheme.outline)),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: isOverdue
                                  ? Colors.red
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.MMMd().format(debt.dueDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isOverdue
                                    ? Colors.red
                                    : theme.colorScheme.outline,
                                fontWeight: isOverdue
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (val) {
                    if (val == 'toggle') {
                      ref
                          .read(debtControllerProvider.notifier)
                          .toggleSettled(
                            debtId: debt.id,
                            isSettled: !debt.isSettled,
                          );
                    } else if (val == 'delete') {
                      ref
                          .read(debtControllerProvider.notifier)
                          .deleteDebt(debt.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        debt.isSettled ? 'Mark as Active' : 'Mark as Settled',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete Record',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Balances & Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.isSettled ? 'Settled' : 'Remaining Balance',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(debt.remainingAmount),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: debt.isSettled ? Colors.grey : primaryColor,
                        decoration: debt.isSettled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Original',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.format(debt.initialAmount),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  debt.isSettled ? Colors.grey : primaryColor,
                ),
              ),
            ),

            if (debt.notes != null && debt.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                debt.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!debt.isSettled) ...[
                  OutlinedButton.icon(
                    onPressed: () => _showRecordPaymentDialog(context, debt),
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    label: const Text('Record Payment'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      ref
                          .read(debtControllerProvider.notifier)
                          .toggleSettled(
                            debtId: debt.id,
                            isSettled: true,
                          );
                    },
                    child: const Text('Settle Full'),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(debtControllerProvider.notifier)
                          .toggleSettled(
                            debtId: debt.id,
                            isSettled: false,
                          );
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Reopen'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, Debt debt) {
    showDialog(
      context: context,
      builder: (ctx) => _RecordPaymentDialog(debt: debt),
    );
  }
}

/// Dialog to create a new debt record.
class _CreateDebtDialog extends ConsumerStatefulWidget {
  const _CreateDebtDialog();

  @override
  ConsumerState<_CreateDebtDialog> createState() => _CreateDebtDialogState();
}

class _CreateDebtDialogState extends ConsumerState<_CreateDebtDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DebtType _type = DebtType.lent;
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Debt / Loan Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Person / Entity Name',
                hintText: 'e.g. Alice, Bob, Landlord',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DebtType>(
              segments: const [
                ButtonSegment(
                  value: DebtType.lent,
                  label: Text('Lent'),
                  icon: Icon(Icons.call_made_rounded),
                ),
                ButtonSegment(
                  value: DebtType.borrowed,
                  label: Text('Borrowed'),
                  icon: Icon(Icons.call_received_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() => _type = set.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total Amount',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dueDate == null
                        ? 'No Due Date'
                        : 'Due: ${DateFormat.yMMMd().format(_dueDate!)}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(_dueDate == null ? 'Set Due Date' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'e.g. Dinner split, Emergency loan',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            final amount = double.tryParse(_amountController.text.trim());
            if (name.isNotEmpty && amount != null && amount > 0) {
              await ref.read(debtControllerProvider.notifier).createDebt(
                    personName: name,
                    type: _type,
                    initialAmount: amount,
                    dueDate: _dueDate,
                    notes: _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save Entry'),
        ),
      ],
    );
  }
}

/// Dialog to record an incremental or full payment.
class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final Debt debt;

  const _RecordPaymentDialog({required this.debt});

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  late final TextEditingController _amountController;
  final _notesController = TextEditingController();
  DateTime _paidAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default to remaining amount for convenient 1-tap full settlement
    _amountController = TextEditingController(
      text: widget.debt.remainingAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    return AlertDialog(
      title: Text('Record Payment: ${widget.debt.personName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Remaining: ${currency.format(widget.debt.remainingAmount)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paid: ${DateFormat.yMMMd().format(_paidAt)}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paidAt,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _paidAt = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Change Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Payment Note (Optional)',
                hintText: 'e.g. Cash, Venmo, Partial transfer',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final val = double.tryParse(_amountController.text.trim());
            if (val != null && val > 0) {
              await ref.read(debtControllerProvider.notifier).recordPayment(
                    debtId: widget.debt.id,
                    amount: val,
                    paidAt: _paidAt,
                    notes: _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
                  );
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Save Payment'),
        ),
      ],
    );
  }
}
