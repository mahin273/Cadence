import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/goals_provider.dart';

/// Modal dialog for configuring and creating a new daily or weekly goal.
class CreateGoalDialog extends ConsumerStatefulWidget {
  const CreateGoalDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const CreateGoalDialog(),
    );
  }

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController(text: 'glasses');

  String _selectedType = 'water';
  final String _period = 'daily';
  String _targetType = 'at_least';
  bool _isSaving = false;

  final Map<String, ({String defaultTitle, String defaultUnit, double defaultValue, String defaultTargetType})> _presets = {
    'water': (
      defaultTitle: 'Daily Water Intake',
      defaultUnit: 'glasses',
      defaultValue: 8.0,
      defaultTargetType: 'at_least',
    ),
    'steps': (
      defaultTitle: 'Daily Steps',
      defaultUnit: 'steps',
      defaultValue: 10000.0,
      defaultTargetType: 'at_least',
    ),
    'spend': (
      defaultTitle: 'Daily Spending Cap',
      defaultUnit: '\$',
      defaultValue: 50.0,
      defaultTargetType: 'at_most',
    ),
    'study': (
      defaultTitle: 'Focused Study Time',
      defaultUnit: 'hours',
      defaultValue: 2.0,
      defaultTargetType: 'at_least',
    ),
    'habit': (
      defaultTitle: 'Morning Routine Habit',
      defaultUnit: 'times',
      defaultValue: 1.0,
      defaultTargetType: 'at_least',
    ),
    'custom': (
      defaultTitle: 'Custom Target',
      defaultUnit: 'units',
      defaultValue: 5.0,
      defaultTargetType: 'at_least',
    ),
  };

  @override
  void initState() {
    super.initState();
    _applyPreset('water');
  }

  void _applyPreset(String type) {
    final preset = _presets[type]!;
    _selectedType = type;
    _titleController.text = preset.defaultTitle;
    _unitController.text = preset.defaultUnit;
    _targetValueController.text = preset.defaultValue == preset.defaultValue.roundToDouble()
        ? preset.defaultValue.toInt().toString()
        : preset.defaultValue.toString();
    _targetType = preset.defaultTargetType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final targetVal = double.tryParse(_targetValueController.text.trim());
    if (targetVal == null || targetVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target value must be greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(goalsControllerProvider).createGoal(
            title: _titleController.text.trim(),
            goalType: _selectedType,
            targetValue: targetVal,
            unit: _unitController.text.trim(),
            period: _period,
            targetType: _targetType,
          );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create New Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goal Type',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'water', child: Text('💧 Water Intake')),
                  DropdownMenuItem(value: 'steps', child: Text('🚶 Steps Count')),
                  DropdownMenuItem(value: 'spend', child: Text('💳 Spending Limit')),
                  DropdownMenuItem(value: 'study', child: Text('📚 Study Time')),
                  DropdownMenuItem(value: 'habit', child: Text('✅ Habit Completion')),
                  DropdownMenuItem(value: 'custom', child: Text('⭐ Custom Goal')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _applyPreset(val));
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Goal Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _targetValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Target Value',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) {
                          return 'Enter > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                'Direction',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'at_least',
                    label: Text('Min (At Least)'),
                  ),
                  ButtonSegment(
                    value: 'at_most',
                    label: Text('Max (Cap)'),
                  ),
                ],
                selected: {_targetType},
                onSelectionChanged: (s) {
                  setState(() => _targetType = s.first);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Goal'),
        ),
      ],
    );
  }
}
