import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';

/// Renders budget burn-rate progress cards with visual threshold cues.
class BudgetProgressSection extends ConsumerWidget {
  const BudgetProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProgressListProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (budgets.isEmpty) {
      return Card(
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.savings_outlined,
                size: 32,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Monthly Budgets Set',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set spending limits to track burn rates and prevent overspending.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _showSetBudgetDialog(context, ref),
                child: const Text('Set Budget'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Limits',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showSetBudgetDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Budget'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 135,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = budgets[index];
              return _BudgetCard(progress: item);
            },
          ),
        ),
      ],
    );
  }

  void _showSetBudgetDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    String selectedCategory = 'All';
    final categories = [
      'All',
      'Food',
      'Transport',
      'Housing',
      'Utilities',
      'Entertainment',
      'Health',
      'Shopping',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Set Monthly Budget'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Category:'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) selectedCategory = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Limit',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim());
                    if (amount != null && amount > 0) {
                      await ref.read(financeControllerProvider).setBudget(
                            category: selectedCategory,
                            monthlyLimit: amount,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save Limit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetProgress progress;

  const _BudgetCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final budget = progress.budget;

    // Determine visual status
    final Color progressColor;
    if (progress.isOverBudget) {
      progressColor = colorScheme.error;
    } else if (progress.percentage >= 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    final percentInt = (progress.percentage * 100).toInt();

    return Container(
      width: 250,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: progress.isOverBudget
            ? colorScheme.errorContainer.withAlpha(80)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: progress.isOverBudget
            ? Border.all(color: colorScheme.error, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  budget.category == 'All' ? 'Overall Monthly' : budget.category,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: progressColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress.isOverBudget ? '$percentInt% OVER' : '$percentInt%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.percentage.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: progressColor,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '\$${progress.spent.toStringAsFixed(2)} spent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'of \$${budget.monthlyLimit.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            progress.isOverBudget
                ? '\$${(-progress.remaining).toStringAsFixed(2)} over budget'
                : '\$${progress.remaining.toStringAsFixed(2)} left to spend',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: progress.isOverBudget
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
