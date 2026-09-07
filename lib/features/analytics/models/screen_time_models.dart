import 'package:flutter/material.dart';

/// Categories for mobile applications.
enum AppCategory {
  social('social', 'Social', Colors.pinkAccent, Icons.people_alt_rounded),
  entertainment('entertainment', 'Entertainment', Colors.purpleAccent, Icons.movie_filter_rounded),
  productivity('productivity', 'Productivity', Colors.blueAccent, Icons.work_history_rounded),
  communication('communication', 'Communication', Colors.teal, Icons.chat_bubble_rounded),
  utilities('utilities', 'Utilities', Colors.orangeAccent, Icons.construction_rounded);

  final String id;
  final String label;
  final Color color;
  final IconData icon;

  const AppCategory(this.id, this.label, this.color, this.icon);

  static AppCategory fromId(String id) {
    return AppCategory.values.firstWhere(
      (c) => c.id.toLowerCase() == id.toLowerCase(),
      orElse: () => AppCategory.utilities,
    );
  }
}

/// Single application usage entry.
class AppUsageInfo {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int durationMinutes;

  const AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.durationMinutes,
  });

  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  factory AppUsageInfo.fromMap(Map<String, dynamic> map) {
    return AppUsageInfo(
      packageName: map['packageName'] as String? ?? 'unknown',
      appName: map['appName'] as String? ?? 'App',
      category: AppCategory.fromId(map['category'] as String? ?? 'utilities'),
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Daily aggregated screen time metrics.
class ScreenTimeSummary {
  final DateTime date;
  final int totalMinutes;
  final Map<AppCategory, int> categoryMinutes;
  final List<AppUsageInfo> apps;

  const ScreenTimeSummary({
    required this.date,
    required this.totalMinutes,
    required this.categoryMinutes,
    required this.apps,
  });

  String get formattedTotal {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  double categoryPercentage(AppCategory category) {
    if (totalMinutes == 0) return 0.0;
    final catMin = categoryMinutes[category] ?? 0;
    return (catMin / totalMinutes).clamp(0.0, 1.0);
  }

  AppCategory get topCategory {
    if (categoryMinutes.isEmpty) return AppCategory.utilities;
    var maxCat = AppCategory.utilities;
    var maxMinutes = -1;
    for (final entry in categoryMinutes.entries) {
      if (entry.value > maxMinutes) {
        maxMinutes = entry.value;
        maxCat = entry.key;
      }
    }
    return maxCat;
  }
}
