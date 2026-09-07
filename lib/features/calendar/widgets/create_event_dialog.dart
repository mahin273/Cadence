import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';

/// Modal dialog to create or edit a Calendar Event.
class CreateCalendarEventDialog extends ConsumerStatefulWidget {
  final CalendarEvent? existingEvent;
  final DateTime? initialDate;

  const CreateCalendarEventDialog({
    super.key,
    this.existingEvent,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    CalendarEvent? existingEvent,
    DateTime? initialDate,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CreateCalendarEventDialog(
        existingEvent: existingEvent,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<CreateCalendarEventDialog> createState() =>
      _CreateCalendarEventDialogState();
}

class _CreateCalendarEventDialogState
    extends ConsumerState<CreateCalendarEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  late String _selectedCategory;
  int? _customColorValue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event != null) {
      _titleController = TextEditingController(text: event.title);
      _descriptionController = TextEditingController(text: event.description ?? '');
      final startLocal = event.startTime.toLocal();
      final endLocal = event.endTime.toLocal();
      _selectedDate = DateTime(startLocal.year, startLocal.month, startLocal.day);
      _startTime = TimeOfDay(hour: startLocal.hour, minute: startLocal.minute);
      _endTime = TimeOfDay(hour: endLocal.hour, minute: endLocal.minute);
      _isAllDay = event.isAllDay;
      _selectedCategory = event.category;
      _customColorValue = event.colorValue;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      final baseDate = widget.initialDate ?? DateTime.now();
      _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
      final now = DateTime.now();
      _startTime = TimeOfDay(hour: now.hour, minute: 0);
      _endTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _isAllDay = false;
      _selectedCategory = 'personal';
      _customColorValue = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Automatically bump end time if it falls before or equals start time
        final startMins = picked.hour * 60 + picked.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          final newEndMins = (startMins + 60) % (24 * 60);
          _endTime = TimeOfDay(hour: newEndMins ~/ 60, minute: newEndMins % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime startDateTime;
    DateTime endDateTime;

    if (_isAllDay) {
      startDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      endDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    } else {
      startDateTime = _combineDateAndTime(_selectedDate, _startTime);
      endDateTime = _combineDateAndTime(_selectedDate, _endTime);

      if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final controller = ref.read(calendarControllerProvider);
      final catConfig = CalendarCategoryConfig.getCategory(_selectedCategory);
      final chosenColor = _customColorValue ?? catConfig.defaultColor.toARGB32();

      if (widget.existingEvent != null) {
        await controller.updateEvent(
          id: widget.existingEvent!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          colorValue: chosenColor,
          category: _selectedCategory,
        );
      } else {
        await controller.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          startTime: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          colorValue: chosenColor,
          category: _selectedCategory,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingEvent != null;

    final dateFormatter = DateFormat('EEE, MMM d, yyyy');

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_calendar_rounded : Icons.event_available_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(isEditing ? 'Edit Event' : 'New Calendar Event'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Event Title',
                    hintText: 'e.g. Sprint Planning, Deep Study',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  autofocus: !isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an event title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Date Selector
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateFormatter.format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // All Day Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All-day event'),
                  value: _isAllDay,
                  onChanged: (val) {
                    setState(() => _isAllDay = val);
                  },
                ),

                // Time Pickers (visible if not all-day)
                if (!_isAllDay) ...[
                  Row(
                    children: [
                      // Start Time
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Starts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _startTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // End Time
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                              vertical: 10.0,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ends',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _endTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Category Selection Chips
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: CalendarCategoryConfig.presets.map((preset) {
                    final isSelected = _selectedCategory == preset.key;
                    return FilterChip(
                      selected: isSelected,
                      avatar: Icon(
                        preset.icon,
                        size: 16,
                        color: isSelected ? Colors.white : preset.defaultColor,
                      ),
                      label: Text(preset.label),
                      selectedColor: preset.defaultColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = preset.key;
                            _customColorValue = preset.defaultColor.toARGB32();
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Location (Optional)',
                    hintText: 'Add agenda details, room link, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveEvent,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
