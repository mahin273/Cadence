import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine_models.dart';
import '../providers/routines_provider.dart';

/// Modal dialog for authoring a new daily routine and its initial checklist items.
class CreateRoutineDialog extends ConsumerStatefulWidget {
  const CreateRoutineDialog({super.key});

  @override
  ConsumerState<CreateRoutineDialog> createState() =>
      _CreateRoutineDialogState();
}

class _CreateRoutineDialogState extends ConsumerState<CreateRoutineDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  RoutinePhase _selectedPhase = RoutinePhase.morning;

  final List<TextEditingController> _stepControllers = [
    TextEditingController(text: 'Drink 500ml water'),
    TextEditingController(text: 'Review daily top 3 priorities'),
    TextEditingController(text: '10 min physical mobility'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addStepField() {
    setState(() {
      _stepControllers.add(TextEditingController());
    });
  }

  void _removeStepField(int index) {
    if (_stepControllers.length > 1) {
      setState(() {
        final controller = _stepControllers.removeAt(index);
        controller.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: _selectedPhase.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_selectedPhase.icon,
                      color: _selectedPhase.color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'New Daily Routine',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Routine Title',
                        hintText: 'e.g. Morning Protocol',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'e.g. Essential habits before opening screens',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Circadian Phase Selector
                    Text(
                      'Circadian Phase',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<RoutinePhase>(
                      segments: const [
                        ButtonSegment(
                          value: RoutinePhase.morning,
                          label: Text('Morning'),
                          icon: Icon(Icons.wb_sunny_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: RoutinePhase.evening,
                          label: Text('Evening'),
                          icon: Icon(Icons.nightlight_round, size: 16),
                        ),
                        ButtonSegment(
                          value: RoutinePhase.anytime,
                          label: Text('Anytime'),
                          icon: Icon(Icons.schedule_rounded, size: 16),
                        ),
                      ],
                      selected: {_selectedPhase},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) {
                          setState(() => _selectedPhase = set.first);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Initial Checklist Steps
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checklist Steps',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Step'),
                          onPressed: _addStepField,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stepControllers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stepControllers[index],
                                decoration: InputDecoration(
                                  hintText: 'Step ${index + 1}',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 10.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                              ),
                            ),
                            if (_stepControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                color: colorScheme.error,
                                onPressed: () => _removeStepField(index),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) return;

                    final itemTitles = _stepControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    await ref.read(routinesControllerProvider).createRoutine(
                          title: title,
                          description: _descController.text.trim().isEmpty
                              ? null
                              : _descController.text.trim(),
                          timeOfDay: _selectedPhase.id,
                          colorValue: _selectedPhase.color.toARGB32(),
                          itemTitles: itemTitles,
                        );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Create Routine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
