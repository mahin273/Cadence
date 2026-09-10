import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/debt_models.dart';
import '../providers/debt_provider.dart';

/// Public "record debt / IOU" dialog, shared by the Finance ledger and the
/// global quick-add palette (Chunk 24). Mirrors the ledger's creation flow.
class CreateDebtDialog extends ConsumerStatefulWidget {
  const CreateDebtDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CreateDebtDialog(),
    );
  }

  @override
  ConsumerState<CreateDebtDialog> createState() => _CreateDebtDialogState();
}

class _CreateDebtDialogState extends ConsumerState<CreateDebtDialog> {
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
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
