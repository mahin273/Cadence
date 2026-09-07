import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/analytics/models/screen_time_models.dart';
import 'package:cadence/features/analytics/services/screen_time_platform_service.dart';
import 'package:cadence/features/analytics/providers/screen_time_provider.dart';

void main() {
  group('ScreenTime Models & Summary Formulas', () {
    test('AppUsageInfo formats duration into hours and minutes', () {
      const app1 = AppUsageInfo(
        packageName: 'pkg.youtube',
        appName: 'YouTube',
        category: AppCategory.entertainment,
        durationMinutes: 75,
      );
      expect(app1.formattedDuration, '1h 15m');

      const app2 = AppUsageInfo(
        packageName: 'pkg.notion',
        appName: 'Notion',
        category: AppCategory.productivity,
        durationMinutes: 42,
      );
      expect(app2.formattedDuration, '42m');
    });

    test('ScreenTimeSummary computes totals, percentages and top category accurately', () {
      final summary = ScreenTimeSummary(
        date: DateTime(2026, 9, 8),
        totalMinutes: 120,
        categoryMinutes: {
          AppCategory.productivity: 60,
          AppCategory.entertainment: 40,
          AppCategory.social: 20,
        },
        apps: const [
          AppUsageInfo(
            packageName: 'pkg.code',
            appName: 'VS Code',
            category: AppCategory.productivity,
            durationMinutes: 60,
          ),
          AppUsageInfo(
            packageName: 'pkg.yt',
            appName: 'YouTube',
            category: AppCategory.entertainment,
            durationMinutes: 40,
          ),
          AppUsageInfo(
            packageName: 'pkg.insta',
            appName: 'Instagram',
            category: AppCategory.social,
            durationMinutes: 20,
          ),
        ],
      );

      expect(summary.formattedTotal, '2h 0m');
      expect(summary.categoryPercentage(AppCategory.productivity), 0.5);
      expect(summary.categoryPercentage(AppCategory.entertainment), closeTo(0.333, 0.01));
      expect(summary.categoryPercentage(AppCategory.communication), 0.0);
      expect(summary.topCategory, AppCategory.productivity);
    });
  });

  group('ScreenTime Database Operations & Controller', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          screenTimeServiceProvider.overrideWithValue(
            const ScreenTimePlatformService(forceMock: true),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('syncScreenTime populates SQLite snapshots via PlatformService', () async {
      final date = DateTime(2026, 9, 8);
      final controller = container.read(screenTimeControllerProvider.notifier);

      await controller.syncScreenTime(date);

      final snapshots = await db.getScreenTimeForDate(date);
      expect(snapshots.length, 5);
      expect(snapshots.first.appName, 'YouTube');
      expect(snapshots.first.durationMinutes, 65);
      expect(snapshots.first.category, 'entertainment');

      // Syncing a second time replaces existing snapshots cleanly
      await controller.syncScreenTime(date);
      final refetched = await db.getScreenTimeForDate(date);
      expect(refetched.length, 5);
    });

    test('ScreenTimeDateNotifier navigates previous and next days without exceeding today', () {
      final notifier = container.read(selectedScreenTimeDateProvider.notifier);
      final initialDate = container.read(selectedScreenTimeDateProvider);

      // Cannot advance past today
      notifier.nextDay();
      expect(container.read(selectedScreenTimeDateProvider), initialDate);

      // Go to previous day
      notifier.previousDay();
      expect(
        container.read(selectedScreenTimeDateProvider),
        initialDate.subtract(const Duration(days: 1)),
      );

      // Now nextDay works
      notifier.nextDay();
      expect(container.read(selectedScreenTimeDateProvider), initialDate);
    });

    test('ScreenTimePlatformService mock returns deterministic fallback', () async {
      const service = ScreenTimePlatformService(forceMock: true);
      final hasPermission = await service.checkPermission();
      expect(hasPermission, isTrue);

      final usage = await service.getDailyUsage(date: DateTime.now());
      expect(usage.isNotEmpty, isTrue);
      expect(usage.any((u) => u.appName == 'YouTube'), isTrue);
      expect(usage.any((u) => u.category == AppCategory.productivity), isTrue);
    });
  });
}
