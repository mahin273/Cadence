import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// Supported view modes in the Agenda Planner.
enum CalendarViewMode {
  day,
  timeline,
  week,
}

/// Predefined category configuration with icons and default colors.
class CalendarCategoryConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color defaultColor;

  const CalendarCategoryConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.defaultColor,
  });

  static const List<CalendarCategoryConfig> presets = [
    CalendarCategoryConfig(
      key: 'work',
      label: 'Deep Work',
      icon: Icons.psychology_rounded,
      defaultColor: Color(0xFF3B82F6), // Blue
    ),
    CalendarCategoryConfig(
      key: 'study',
      label: 'Study',
      icon: Icons.school_outlined,
      defaultColor: Color(0xFF8B5CF6), // Purple
    ),
    CalendarCategoryConfig(
      key: 'routine',
      label: 'Routine',
      icon: Icons.checklist_rtl_rounded,
      defaultColor: Color(0xFFFFB74D), // Orange
    ),
    CalendarCategoryConfig(
      key: 'movement',
      label: 'Movement',
      icon: Icons.directions_run_rounded,
      defaultColor: Color(0xFF10B981), // Emerald
    ),
    CalendarCategoryConfig(
      key: 'personal',
      label: 'Personal',
      icon: Icons.person_outline_rounded,
      defaultColor: Color(0xFF06B6D4), // Cyan
    ),
    CalendarCategoryConfig(
      key: 'health',
      label: 'Health',
      icon: Icons.favorite_outline_rounded,
      defaultColor: Color(0xFFEF4444), // Rose
    ),
    CalendarCategoryConfig(
      key: 'rest',
      label: 'Rest',
      icon: Icons.nightlight_round,
      defaultColor: Color(0xFFF59E0B), // Amber
    ),
  ];

  static CalendarCategoryConfig getCategory(String key) {
    return presets.firstWhere(
      (c) => c.key.toLowerCase() == key.toLowerCase(),
      orElse: () => const CalendarCategoryConfig(
        key: 'other',
        label: 'Event',
        icon: Icons.event_note_rounded,
        defaultColor: Color(0xFF64748B),
      ),
    );
  }
}

/// Composite model linking a scheduled event with its conflict status.
class TimeBlockWithConflict {
  final CalendarEvent event;
  final bool hasConflict;
  final List<String> conflictingEventIds;

  const TimeBlockWithConflict({
    required this.event,
    this.hasConflict = false,
    this.conflictingEventIds = const [],
  });

  /// Duration of this time block in minutes.
  int get durationMinutes =>
      event.endTime.difference(event.startTime).inMinutes;

  /// Start minute offset from midnight (0 to 1440).
  int get startMinutesFromMidnight =>
      event.startTime.hour * 60 + event.startTime.minute;

  /// End minute offset from midnight.
  int get endMinutesFromMidnight =>
      event.endTime.hour * 60 + event.endTime.minute;
}

/// Algorithm detecting temporal collisions between time blocks.
class TimeConflictDetector {
  static List<TimeBlockWithConflict> detectConflicts(List<CalendarEvent> events) {
    final sorted = List<CalendarEvent>.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final conflictMap = <String, Set<String>>{};

    for (int i = 0; i < sorted.length; i++) {
      for (int j = i + 1; j < sorted.length; j++) {
        if (!sorted[j].startTime.isBefore(sorted[i].endTime)) {
          break;
        }

        final maxStart = sorted[i].startTime.isAfter(sorted[j].startTime)
            ? sorted[i].startTime
            : sorted[j].startTime;
        final minEnd = sorted[i].endTime.isBefore(sorted[j].endTime)
            ? sorted[i].endTime
            : sorted[j].endTime;

        if (maxStart.isBefore(minEnd)) {
          conflictMap.putIfAbsent(sorted[i].id, () => {}).add(sorted[j].id);
          conflictMap.putIfAbsent(sorted[j].id, () => {}).add(sorted[i].id);
        }
      }
    }

    return sorted.map((e) {
      final conflicts = conflictMap[e.id]?.toList() ?? [];
      return TimeBlockWithConflict(
        event: e,
        hasConflict: conflicts.isNotEmpty,
        conflictingEventIds: conflicts,
      );
    }).toList();
  }
}
