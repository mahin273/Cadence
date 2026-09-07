import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/net_worth_models.dart';
import '../providers/net_worth_provider.dart';
import '../widgets/net_worth_chart.dart';

/// Full screen view for managing wealth accounts, updating balances, and inspecting trajectories.
class NetWorthView extends ConsumerWidget {
  const NetWorthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summaryAsync = ref.watch(netWorthSummaryProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Net Worth & Accounts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Add Account',
            onPressed: () => _showCreateAccountDialog(context, ref),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading accounts: $e')),
        data: (summary) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            children: [
              // High-level Net Worth Summary Banner
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Net Worth',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormatter.format(summary.netWorth),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: summary.netWorth >= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF43F5E),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assets',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  currencyFormatter.format(summary.totalAssets),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Liabilities',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  currencyFormatter.format(summary.totalLiabilities),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF43F5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Net Worth Chart
              const NetWorthChart(),

              const SizedBox(height: 24),

              // Assets Section
              _buildSectionHeader(
                context,
                title: 'Assets',
                count: summary.assetAccounts.length,
                totalAmount: currencyFormatter.format(summary.totalAssets),
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              if (summary.assetAccounts.isEmpty)
                _buildEmptyAccountHint(context, 'No asset accounts registered yet')
              else
                ...summary.assetAccounts.map(
                  (acc) => _AccountTile(
                    item: acc,
                    onUpdateBalance: () => _showUpdateBalanceDialog(context, ref, acc),
                    onDeleteAccount: () => _confirmDeleteAccount(context, ref, acc),
                  ),
                ),

              const SizedBox(height: 24),

              // Liabilities Section
              _buildSectionHeader(
                context,
                title: 'Liabilities & Debts',
                count: summary.liabilityAccounts.length,
                totalAmount: currencyFormatter.format(summary.totalLiabilities),
                color: const Color(0xFFF43F5E),
              ),
              const SizedBox(height: 8),
              if (summary.liabilityAccounts.isEmpty)
                _buildEmptyAccountHint(context, 'No liabilities or debts tracked')
              else
                ...summary.liabilityAccounts.map(
                  (acc) => _AccountTile(
                    item: acc,
                    onUpdateBalance: () => _showUpdateBalanceDialog(context, ref, acc),
                    onDeleteAccount: () => _confirmDeleteAccount(context, ref, acc),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account'),
        onPressed: () => _showCreateAccountDialog(context, ref),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required String totalAmount,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Text(
          totalAmount,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAccountHint(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _CreateAccountDialog(),
    );
  }

  void _showUpdateBalanceDialog(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) {
    showDialog(
      context: context,
      builder: (_) => _UpdateBalanceDialog(item: item),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    AccountWithBalance item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.account.name}?'),
        content: const Text(
          'This will delete the account and all of its recorded balance snapshots. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(netWorthControllerProvider.notifier)
                  .deleteAccount(item.account.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountWithBalance item;
  final VoidCallback onUpdateBalance;
  final VoidCallback onDeleteAccount;

  const _AccountTile({
    required this.item,
    required this.onUpdateBalance,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAsset = item.accountType == AccountType.asset;
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateStr = item.lastUpdated != null
        ? 'Updated ${DateFormat('MMM d').format(item.lastUpdated!)}'
        : 'No balance recorded';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Color(item.account.colorValue).withValues(alpha: 0.15),
          child: Icon(
            item.subType.icon,
            color: Color(item.account.colorValue),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.account.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              currencyFormatter.format(item.currentBalance),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isAsset ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              ),
            ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item.subType.label} • $dateStr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onUpdateBalance,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Update', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete Account',
                  onPressed: onDeleteAccount,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateAccountDialog extends ConsumerStatefulWidget {
  const _CreateAccountDialog();

  @override
  ConsumerState<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _selectedType = AccountType.asset;
  AccountSubType _selectedSubType = AccountSubType.checking;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. Chase Checking, Vanguard Roth IRA',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<AccountType>(
              segments: const [
                ButtonSegment(
                  value: AccountType.asset,
                  label: Text('Asset'),
                  icon: Icon(Icons.account_balance_rounded),
                ),
                ButtonSegment(
                  value: AccountType.liability,
                  label: Text('Liability / Debt'),
                  icon: Icon(Icons.credit_card_rounded),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedType = set.first;
                  _selectedSubType = _selectedType == AccountType.asset
                      ? AccountSubType.checking
                      : AccountSubType.creditCard;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountSubType>(
              initialValue: _selectedSubType,
              decoration: const InputDecoration(labelText: 'Account SubType'),
              items: (_selectedType == AccountType.asset
                      ? [
                          AccountSubType.checking,
                          AccountSubType.savings,
                          AccountSubType.investment,
                          AccountSubType.crypto,
                          AccountSubType.cash,
                          AccountSubType.other,
                        ]
                      : [
                          AccountSubType.creditCard,
                          AccountSubType.loan,
                          AccountSubType.mortgage,
                          AccountSubType.other,
                        ])
                  .map((st) => DropdownMenuItem(
                        value: st,
                        child: Row(
                          children: [
                            Icon(st.icon, size: 18),
                            const SizedBox(width: 8),
                            Text(st.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSubType = val);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current Balance (\$)',
                hintText: '0.00',
                prefixText: '\$ ',
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
          onPressed: _save,
          child: const Text('Create Account'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final initialBalance = double.tryParse(_balanceController.text.trim());

    await ref.read(netWorthControllerProvider.notifier).createAccount(
          name: name,
          type: _selectedType,
          subType: _selectedSubType,
          initialBalance: initialBalance,
        );

    if (mounted) Navigator.pop(context);
  }
}

class _UpdateBalanceDialog extends ConsumerStatefulWidget {
  final AccountWithBalance item;

  const _UpdateBalanceDialog({required this.item});

  @override
  ConsumerState<_UpdateBalanceDialog> createState() => _UpdateBalanceDialogState();
}

class _UpdateBalanceDialogState extends ConsumerState<_UpdateBalanceDialog> {
  late final TextEditingController _balanceController;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.item.currentBalance == 0.0
          ? ''
          : widget.item.currentBalance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update ${widget.item.account.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _balanceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Current Balance',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. After paycheck, Market update',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final val = double.tryParse(_balanceController.text.trim());
            if (val != null) {
              await ref.read(netWorthControllerProvider.notifier).recordBalance(
                    accountId: widget.item.account.id,
                    balance: val,
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save Snapshot'),
        ),
      ],
    );
  }
}
