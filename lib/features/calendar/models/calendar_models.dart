import 'package:flutter/material.dart';

/// Supported view modes in the Agenda Planner.
enum CalendarViewMode {
  day,
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
      label: 'Work',
      icon: Icons.work_outline_rounded,
      defaultColor: Color(0xFF3B82F6), // Blue
    ),
    CalendarCategoryConfig(
      key: 'study',
      label: 'Study',
      icon: Icons.school_outlined,
      defaultColor: Color(0xFF8B5CF6), // Purple
    ),
    CalendarCategoryConfig(
      key: 'personal',
      label: 'Personal',
      icon: Icons.person_outline_rounded,
      defaultColor: Color(0xFF10B981), // Emerald
    ),
    CalendarCategoryConfig(
      key: 'health',
      label: 'Health',
      icon: Icons.favorite_outline_rounded,
      defaultColor: Color(0xFFEF4444), // Rose / Red
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
