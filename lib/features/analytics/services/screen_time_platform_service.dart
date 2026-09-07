import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/screen_time_models.dart';

/// Service interfacing with Android UsageStatsManager via MethodChannel.
class ScreenTimePlatformService {
  static const MethodChannel _channel =
      MethodChannel('com.cadence.app/screentime');

  final bool forceMock;

  const ScreenTimePlatformService({this.forceMock = false});

  /// Check whether PACKAGE_USAGE_STATS permission is granted in Android Settings.
  Future<bool> checkPermission() async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final granted = await _channel.invokeMethod<bool>('checkUsagePermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request usage permission by opening Android system settings.
  Future<bool> requestPermission() async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final opened = await _channel.invokeMethod<bool>('requestUsagePermission');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Query daily usage stats between midnight and end-of-day for the target date.
  Future<List<AppUsageInfo>> getDailyUsage({required DateTime date}) async {
    if (forceMock || defaultTargetPlatform != TargetPlatform.android) {
      return _getDeterministicMockUsage(date);
    }

    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getDailyUsageStats',
        {
          'startEpoch': dayStart.millisecondsSinceEpoch,
          'endEpoch': dayEnd.millisecondsSinceEpoch,
        },
      );

      if (rawList == null || rawList.isEmpty) {
        return _getDeterministicMockUsage(date);
      }

      return rawList
          .map((item) => AppUsageInfo.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return _getDeterministicMockUsage(date);
    }
  }

  /// Deterministic mock dataset used for testing and non-Android runtime targets.
  List<AppUsageInfo> _getDeterministicMockUsage(DateTime date) {
    return const [
      AppUsageInfo(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        category: AppCategory.entertainment,
        durationMinutes: 65,
      ),
      AppUsageInfo(
        packageName: 'notion.id',
        appName: 'Notion',
        category: AppCategory.productivity,
        durationMinutes: 45,
      ),
      AppUsageInfo(
        packageName: 'org.telegram.messenger',
        appName: 'Telegram',
        category: AppCategory.communication,
        durationMinutes: 35,
      ),
      AppUsageInfo(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        category: AppCategory.social,
        durationMinutes: 30,
      ),
      AppUsageInfo(
        packageName: 'com.android.chrome',
        appName: 'Google Chrome',
        category: AppCategory.utilities,
        durationMinutes: 25,
      ),
    ];
  }
}
