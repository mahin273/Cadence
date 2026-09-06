import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/entries_provider.dart';

/// Bottom sheet modal allowing users to log any polymorphic entry.
class QuickLogModal extends ConsumerStatefulWidget {
  final String initialType;

  const QuickLogModal({
    super.key,
    this.initialType = 'water',
  });

  static Future<void> show(BuildContext context, {String initialType = 'water'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuickLogModal(initialType: initialType),
    );
  }

  @override
  ConsumerState<QuickLogModal> createState() => _QuickLogModalState();
}

class _QuickLogModalState extends ConsumerState<QuickLogModal> {
  late String _selectedType;
  double _numericValue = 1.0;
  String _unit = 'glass';
  final _noteController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _habitTitleController = TextEditingController();
  final List<String> _tags = [];
  int _selectedMoodIndex = 3; // 1-5 scale, default 3 (Okay)
  String _sleepQuality = 'Restful';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (_selectedType == 'water') {
      _tags.addAll(['Hydration', 'Health']);
    } else if (_selectedType == 'habit') {
      _tags.addAll(['Routine']);
    } else if (_selectedType == 'mood') {
      _tags.addAll(['Reflection']);
    } else if (_selectedType == 'sleep') {
      _tags.addAll(['Rest']);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tagInputController.dispose();
    _habitTitleController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isNotEmpty && !_tags.contains(clean)) {
      setState(() {
        _tags.add(clean);
        _tagInputController.clear();
      });
    }
  }

  Future<void> _submitEntry() async {
    final controller = ref.read(entryControllerProvider);
    Map<String, dynamic> metadata = {};
    String? note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    String? unit = _unit;
    double value = _numericValue;

    if (_selectedType == 'habit') {
      final habitName = _habitTitleController.text.trim().isEmpty
          ? 'Daily Habit'
          : _habitTitleController.text.trim();
      metadata['habit_name'] = habitName;
      value = 1.0;
      unit = 'count';
    } else if (_selectedType == 'mood') {
      value = _selectedMoodIndex.toDouble();
      unit = 'score';
      metadata['mood_label'] = _getMoodLabel(_selectedMoodIndex);
    } else if (_selectedType == 'sleep') {
      metadata['quality'] = _sleepQuality;
      unit = 'hours';
    }

    await controller.logEntry(
      type: _selectedType,
      value: value,
      unit: unit,
      note: note,
      tags: _tags,
      metadata: metadata,
      occurredAt: DateTime.now(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged ${_selectedType.toUpperCase()} entry successfully'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getMoodLabel(int score) {
    switch (score) {
      case 1:
        return 'Awful';
      case 2:
        return 'Low';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Okay';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick Log Entry',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Segmented Category Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'water',
                  icon: Icon(Icons.water_drop_outlined),
                  label: Text('Water'),
                ),
                ButtonSegment(
                  value: 'habit',
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Habit'),
                ),
                ButtonSegment(
                  value: 'mood',
                  icon: Icon(Icons.mood_outlined),
                  label: Text('Mood'),
                ),
                ButtonSegment(
                  value: 'sleep',
                  icon: Icon(Icons.bedtime_outlined),
                  label: Text('Sleep'),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedType = set.first;
                });
              },
            ),

            const SizedBox(height: 20),

            // Category Specific Form Elements
            if (_selectedType == 'water') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_numericValue > 0.5) {
                        setState(() => _numericValue -= 0.5);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$_numericValue $_unit',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() => _numericValue += 0.5);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    label: const Text('+1 Glass'),
                    onPressed: () => setState(() {
                      _numericValue = 1.0;
                      _unit = 'glass';
                    }),
                  ),
                  ActionChip(
                    label: const Text('+250 ml'),
                    onPressed: () => setState(() {
                      _numericValue = 250.0;
                      _unit = 'ml';
                    }),
                  ),
                  ActionChip(
                    label: const Text('+500 ml Bottle'),
                    onPressed: () => setState(() {
                      _numericValue = 500.0;
                      _unit = 'ml';
                    }),
                  ),
                ],
              ),
            ] else if (_selectedType == 'habit') ...[
              TextField(
                controller: _habitTitleController,
                decoration: const InputDecoration(
                  labelText: 'Habit Name',
                  hintText: 'e.g. Read 20 pages, Meditate, Morning run',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.task_alt),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Read 20 min'),
                    onPressed: () => _habitTitleController.text = 'Read 20 min',
                  ),
                  ActionChip(
                    label: const Text('Meditation'),
                    onPressed: () => _habitTitleController.text = 'Meditation',
                  ),
                  ActionChip(
                    label: const Text('Deep Work Block'),
                    onPressed: () => _habitTitleController.text = 'Deep Work Block',
                  ),
                ],
              ),
            ] else if (_selectedType == 'mood') ...[
              Text(
                'How are you feeling right now?',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MoodChip(score: 1, label: 'Awful', icon: Icons.sentiment_very_dissatisfied, selected: _selectedMoodIndex == 1, onTap: () => setState(() => _selectedMoodIndex = 1)),
                  _MoodChip(score: 2, label: 'Low', icon: Icons.sentiment_dissatisfied, selected: _selectedMoodIndex == 2, onTap: () => setState(() => _selectedMoodIndex = 2)),
                  _MoodChip(score: 3, label: 'Okay', icon: Icons.sentiment_neutral, selected: _selectedMoodIndex == 3, onTap: () => setState(() => _selectedMoodIndex = 3)),
                  _MoodChip(score: 4, label: 'Good', icon: Icons.sentiment_satisfied, selected: _selectedMoodIndex == 4, onTap: () => setState(() => _selectedMoodIndex = 4)),
                  _MoodChip(score: 5, label: 'Great', icon: Icons.sentiment_very_satisfied, selected: _selectedMoodIndex == 5, onTap: () => setState(() => _selectedMoodIndex = 5)),
                ],
              ),
            ] else if (_selectedType == 'sleep') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Duration: ${_numericValue.toStringAsFixed(1)} hours', style: theme.textTheme.titleMedium),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Restful', label: Text('Restful')),
                      ButtonSegment(value: 'Light', label: Text('Light')),
                    ],
                    selected: {_sleepQuality},
                    onSelectionChanged: (val) => setState(() => _sleepQuality = val.first),
                  ),
                ],
              ),
              Slider(
                value: _numericValue.clamp(1.0, 14.0),
                min: 1.0,
                max: 14.0,
                divisions: 26,
                label: '${_numericValue.toStringAsFixed(1)} hrs',
                onChanged: (val) => setState(() => _numericValue = val),
              ),
            ],

            const SizedBox(height: 16),

            // Note Input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add reflections or context...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),

            const SizedBox(height: 12),

            // Tag Input & Chips
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    decoration: const InputDecoration(
                      labelText: 'Add Tag',
                      hintText: 'e.g. Focus, Wellness',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagInputController.text),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags
                    .map(
                      (tag) => Chip(
                        label: Text('#$tag'),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Entry'),
              onPressed: _submitEntry,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final int score;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.score,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final onColor = selected ? colorScheme.onPrimary : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: onColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onColor,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
