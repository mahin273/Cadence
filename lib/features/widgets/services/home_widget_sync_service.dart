import 'package:drift/drift.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/circadian_theme.dart';
import '../../routines/heatmaps/services/habit_streak_service.dart';
import '../models/widget_sync_data.dart';

/// Sync service orchestrating telemetry updates between Drift SQLite and
/// the native Android Home Screen Glance widget via home_widget.
class HomeWidgetSyncService {
  final AppDatabase db;
  static const String androidWidgetName = 'CadenceGlanceWidget';
  static const String qualifiedAndroidWidgetName = 'com.cadence.cadence.CadenceGlanceWidget';

  HomeWidgetSyncService(this.db);

  /// Aggregates multi-domain metrics for today and dispatches them to HomeWidget storage.
  Future<WidgetSyncData> syncWidget({int? overrideSteps}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    // 1. Focus Minutes Today
    final sessions = await (db.select(db.studySessions)
          ..where((tbl) =>
              tbl.startedAt.isBiggerOrEqualValue(todayStart) &
              tbl.startedAt.isSmallerOrEqualValue(todayEnd)))
        .get();
    int focusMinutes = 0;
    for (final s in sessions) {
      focusMinutes += s.actualSeconds ~/ 60;
    }

    // 2. Water Glasses Today
    final waterEntries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.occurredAt.isBiggerOrEqualValue(todayStart) &
              tbl.occurredAt.isSmallerOrEqualValue(todayEnd) &
              tbl.type.equals('water') &
              tbl.isDeleted.equals(false)))
        .get();
    int waterGlasses = 0;
    for (final e in waterEntries) {
      waterGlasses += e.value.round();
    }

    // 3. Steps Today
    int todaySteps = overrideSteps ?? 0;
    if (todaySteps == 0) {
      final stepEntries = await (db.select(db.entries)
            ..where((tbl) =>
                tbl.occurredAt.isBiggerOrEqualValue(todayStart) &
                tbl.occurredAt.isSmallerOrEqualValue(todayEnd) &
                tbl.type.equals('steps') &
                tbl.isDeleted.equals(false)))
          .get();
      for (final s in stepEntries) {
        todaySteps += s.value.round();
      }
    }

    // 4. Current Habit Streak
    final streakService = HabitStreakService(db);
    final stats = await streakService.calculateConsistencyStats(days: 365);
    final streakDays = stats.currentStreak;

    // 5. Circadian Phase
    final phase = CircadianTheme.getPhase(now);
    final String phaseLabel = switch (phase) {
      CircadianPhase.day => 'Daylight',
      CircadianPhase.dusk => 'Twilight',
      CircadianPhase.night => 'Night',
      CircadianPhase.dawn => 'Dawn',
    };

    final syncData = WidgetSyncData(
      focusMinutes: focusMinutes,
      todaySteps: todaySteps,
      waterGlasses: waterGlasses,
      streakDays: streakDays,
      circadianPhase: phaseLabel,
      lastUpdated: now,
    );

    // 6. Push to HomeWidget Storage (Silently catch PlatformException when running headless/tests)
    try {
      await HomeWidget.saveWidgetData<int>('focus_minutes', syncData.focusMinutes);
      await HomeWidget.saveWidgetData<int>('today_steps', syncData.todaySteps);
      await HomeWidget.saveWidgetData<int>('water_glasses', syncData.waterGlasses);
      await HomeWidget.saveWidgetData<int>('streak_days', syncData.streakDays);
      await HomeWidget.saveWidgetData<String>('circadian_phase', syncData.circadianPhase);
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: qualifiedAndroidWidgetName,
      );
    } catch (_) {
      // Platform channels may be absent during headless unit testing
    }

    return syncData;
  }

  /// Processes quick action intents dispatched from Home Screen widget buttons.
  Future<bool> handleQuickAction(Uri uri, {String userId = 'local_user'}) async {
    if (uri.host != 'quick_action') {
      return false;
    }

    final type = uri.queryParameters['type'];
    if (type == 'water') {
      final now = DateTime.now();
      await db.into(db.entries).insert(
            EntriesCompanion(
              id: Value(const Uuid().v4()),
              userId: Value(userId),
              type: const Value('water'),
              value: const Value(1.0),
              unit: const Value('glasses'),
              occurredAt: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await syncWidget();
      return true;
    }

    return false;
  }
}
