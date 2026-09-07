import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../models/screen_time_models.dart';
import '../services/screen_time_platform_service.dart';

const _uuid = Uuid();

/// Provider for native screen time platform bridge.
final screenTimeServiceProvider = Provider<ScreenTimePlatformService>((ref) {
  return const ScreenTimePlatformService();
});

/// Currently selected date for screen time exploration.
class ScreenTimeDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void previousDay() {
    state = state.subtract(const Duration(days: 1));
  }

  void nextDay() {
    final tomorrow = state.add(const Duration(days: 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!tomorrow.isAfter(today)) {
      state = tomorrow;
    }
  }
}

final selectedScreenTimeDateProvider =
    NotifierProvider<ScreenTimeDateNotifier, DateTime>(
  ScreenTimeDateNotifier.new,
);

/// Checks if Android Usage Access permission is granted.
final screenTimePermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(screenTimeServiceProvider);
  return service.checkPermission();
});

/// Reactive stream of local screen time snapshots stored for the selected date.
final dailyScreenTimeStreamProvider =
    StreamProvider<List<ScreenTimeSnapshot>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final date = ref.watch(selectedScreenTimeDateProvider);
  return db.watchScreenTimeForDate(date);
});

/// Computes aggregated ScreenTimeSummary metrics for the selected date.
final screenTimeSummaryProvider =
    Provider<AsyncValue<ScreenTimeSummary>>((ref) {
  final date = ref.watch(selectedScreenTimeDateProvider);
  final snapshotsAsync = ref.watch(dailyScreenTimeStreamProvider);

  return snapshotsAsync.whenData((snapshots) {
    int totalMinutes = 0;
    final categoryMinutes = <AppCategory, int>{};
    final apps = <AppUsageInfo>[];

    for (final s in snapshots) {
      totalMinutes += s.durationMinutes;
      final category = AppCategory.fromId(s.category);
      categoryMinutes[category] =
          (categoryMinutes[category] ?? 0) + s.durationMinutes;

      apps.add(
        AppUsageInfo(
          packageName: s.packageName,
          appName: s.appName,
          category: category,
          durationMinutes: s.durationMinutes,
        ),
      );
    }

    return ScreenTimeSummary(
      date: date,
      totalMinutes: totalMinutes,
      categoryMinutes: categoryMinutes,
      apps: apps,
    );
  });
});

/// Controller handling screen time synchronization and permissions.
class ScreenTimeController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Synchronize daily usage stats from platform channel into Drift SQLite.
  Future<void> syncScreenTime(DateTime date) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(screenTimeServiceProvider);
      final db = ref.read(appDatabaseProvider);

      final usageList = await service.getDailyUsage(date: date);
      final dayStart = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();

      final companions = usageList.map((app) {
        return ScreenTimeSnapshotsCompanion(
          id: drift.Value(_uuid.v4()),
          date: drift.Value(dayStart),
          packageName: drift.Value(app.packageName),
          appName: drift.Value(app.appName),
          category: drift.Value(app.category.id),
          durationMinutes: drift.Value(app.durationMinutes),
          createdAt: drift.Value(now),
          isSynced: const drift.Value(false),
        );
      }).toList();

      await db.saveScreenTimeSnapshots(dayStart, companions);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Request system usage access permission and refresh permission provider.
  Future<void> requestPermission() async {
    final service = ref.read(screenTimeServiceProvider);
    await service.requestPermission();
    ref.invalidate(screenTimePermissionProvider);
  }
}

final screenTimeControllerProvider =
    NotifierProvider<ScreenTimeController, AsyncValue<void>>(
  ScreenTimeController.new,
);
