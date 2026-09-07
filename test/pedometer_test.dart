import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/movement/models/movement_models.dart';
import 'package:cadence/features/movement/providers/movement_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StepNormalizer Algorithm', () {
    test('normalizes first hardware event as baseline (0 steps)', () {
      final normalizer = StepNormalizer();
      final day = DateTime(2026, 9, 8, 8, 0);

      // Hardware reports 5000 cumulative steps since boot
      final steps = normalizer.onStepCount(5000, day);
      expect(steps, 0);
      expect(normalizer.todayBaseline, 5000);
      expect(normalizer.lastRawCount, 5000);
    });

    test('increments steps as hardware counter increases on same day', () {
      final normalizer = StepNormalizer();
      final day = DateTime(2026, 9, 8, 8, 0);

      normalizer.onStepCount(5000, day);

      // 500 steps later
      var steps = normalizer.onStepCount(5500, day.add(const Duration(minutes: 10)));
      expect(steps, 500);

      // 1200 steps later
      steps = normalizer.onStepCount(6200, day.add(const Duration(minutes: 30)));
      expect(steps, 1200);
    });

    test('recovers from device reboot without losing previously accumulated steps', () {
      final normalizer = StepNormalizer();
      final day = DateTime(2026, 9, 8, 8, 0);

      // Boot baseline: 5000
      normalizer.onStepCount(5000, day);

      // Walked 2000 steps (raw = 7000)
      var steps = normalizer.onStepCount(7000, day.add(const Duration(hours: 2)));
      expect(steps, 2000);

      // Device reboots midday! Sensor drops to 150
      steps = normalizer.onStepCount(150, day.add(const Duration(hours: 3)));
      // Should preserve the 2000 steps plus 0 new steps from new baseline of 150
      expect(steps, 2000);

      // User walks 300 more steps after reboot (raw = 450)
      steps = normalizer.onStepCount(450, day.add(const Duration(hours: 3, minutes: 15)));
      expect(steps, 2300);
    });

    test('resets daily baseline upon midnight rollover to a new day', () {
      final normalizer = StepNormalizer();
      final day1 = DateTime(2026, 9, 8, 23, 30);
      final day2 = DateTime(2026, 9, 9, 0, 15);

      // Day 1: baseline 10,000 -> walked 3,000 steps
      normalizer.onStepCount(10000, day1);
      var stepsDay1 = normalizer.onStepCount(13000, day1.add(const Duration(minutes: 15)));
      expect(stepsDay1, 3000);

      // Day 2 (Midnight passed, raw is 13,050)
      var stepsDay2 = normalizer.onStepCount(13050, day2);
      expect(stepsDay2, 0); // New day starts at 0
      expect(normalizer.todayBaseline, 13050);

      // User walks 400 steps on Day 2
      stepsDay2 = normalizer.onStepCount(13450, day2.add(const Duration(minutes: 30)));
      expect(stepsDay2, 400);
    });
  });

  group('MovementState Metrics Calculation', () {
    test('computes distance, calories, and progress correctly', () {
      const state = MovementState(
        stepsToday: 5000,
        dailyTarget: 10000,
        pedestrianStatus: 'walking',
      );

      // Distance: 5000 * 0.762 / 1000 = 3.81 km
      expect(state.estimatedDistanceKm, closeTo(3.81, 0.01));

      // Calories: 5000 * 0.04 = 200 kcal
      expect(state.estimatedCaloriesKcal, closeTo(200.0, 0.1));

      // Progress: 5000 / 10000 = 0.5
      expect(state.progressRatio, 0.5);

      expect(state.isWalking, isTrue);
    });
  });

  group('Movement Database Logging & Providers', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-pedometer-user';

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => testUserId),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('logManualSteps persists steps to Drift entries table and updates today total', () async {
      final notifier = container.read(stepTrackingProvider.notifier);

      // Log 1500 steps
      await notifier.logManualSteps(1500, notes: 'Morning walk');

      // Verify state updated
      expect(container.read(stepTrackingProvider).stepsToday, 1500);

      // Verify row in Drift entries table
      final allEntries = await db.watchEntriesByType('steps').first;
      expect(allEntries.length, 1);
      expect(allEntries.first.type, 'steps');
      expect(allEntries.first.value, 1500.0);
      expect(allEntries.first.unit, 'steps');
      expect(allEntries.first.userId, testUserId);

      // Log another 1000 steps
      await notifier.logManualSteps(1000, notes: 'Afternoon run');
      expect(container.read(stepTrackingProvider).stepsToday, 2500);

      // Verify stream provider reading today steps from DB
      final dbSteps = await db.watchEntriesForDay(DateTime.now()).first;
      final stepSum = dbSteps
          .where((e) => e.type == 'steps')
          .fold<int>(0, (acc, e) => acc + e.value.toInt());
      expect(stepSum, 2500);
    });
  });
}
