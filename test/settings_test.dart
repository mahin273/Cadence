import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/settings/settings_models.dart';
import 'package:cadence/core/settings/settings_provider.dart';
import 'package:cadence/features/settings/presentation/settings_screen.dart';

void main() {
  group('AppSettings Model and Provider Tests', () {
    test('Default values are initialized correctly', () {
      const settings = AppSettings();
      expect(settings.stepGoal, 10000);
      expect(settings.waterGoalGlasses, 8.0);
      expect(settings.sleepGoalHours, 8.0);
      expect(settings.screenTimeLimitHours, 4.0);
      expect(settings.pomodoroFocusMinutes, 25);
      expect(settings.pomodoroShortBreakMinutes, 5);
      expect(settings.pomodoroLongBreakMinutes, 15);
      expect(settings.pomodoroAutoStartBreaks, isFalse);
      expect(settings.useMetricUnits, isTrue);
      expect(settings.highAccuracyGps, isTrue);
      expect(settings.defaultCurrency, '\$');
      expect(settings.budgetAlertThreshold, 0.8);
      expect(settings.syncWifiOnly, isFalse);
    });

    test('Serialization toMap and fromMap preserves all fields', () {
      const original = AppSettings(
        stepGoal: 12000,
        waterGoalGlasses: 10.0,
        sleepGoalHours: 7.5,
        screenTimeLimitHours: 3.5,
        pomodoroFocusMinutes: 30,
        pomodoroShortBreakMinutes: 6,
        pomodoroLongBreakMinutes: 20,
        pomodoroAutoStartBreaks: true,
        routineResetHour: 4,
        useMetricUnits: false,
        highAccuracyGps: false,
        autoPauseTracking: true,
        defaultCurrency: '€',
        budgetAlertThreshold: 0.9,
        syncWifiOnly: true,
      );

      final map = original.toMap();
      final restored = AppSettings.fromMap(map);

      expect(restored.stepGoal, 12000);
      expect(restored.waterGoalGlasses, 10.0);
      expect(restored.sleepGoalHours, 7.5);
      expect(restored.screenTimeLimitHours, 3.5);
      expect(restored.pomodoroFocusMinutes, 30);
      expect(restored.pomodoroShortBreakMinutes, 6);
      expect(restored.pomodoroLongBreakMinutes, 20);
      expect(restored.pomodoroAutoStartBreaks, isTrue);
      expect(restored.routineResetHour, 4);
      expect(restored.useMetricUnits, isFalse);
      expect(restored.highAccuracyGps, isFalse);
      expect(restored.autoPauseTracking, isTrue);
      expect(restored.defaultCurrency, '€');
      expect(restored.budgetAlertThreshold, 0.9);
      expect(restored.syncWifiOnly, isTrue);
    });

    test('SettingsNotifier updates mutate state predictably', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      expect(container.read(appSettingsProvider).stepGoal, 10000);

      notifier.updateStepGoal(8500);
      expect(container.read(appSettingsProvider).stepGoal, 8500);

      notifier.updateWaterGoal(9.5);
      expect(container.read(appSettingsProvider).waterGoalGlasses, 9.5);

      notifier.updateSleepGoal(7.0);
      expect(container.read(appSettingsProvider).sleepGoalHours, 7.0);

      notifier.updateMeasurementUnits(useMetric: false);
      expect(container.read(appSettingsProvider).useMetricUnits, isFalse);

      notifier.updateFinanceSettings(currency: '£', threshold: 0.85);
      expect(container.read(appSettingsProvider).defaultCurrency, '£');
      expect(container.read(appSettingsProvider).budgetAlertThreshold, 0.85);

      notifier.updateSyncSettings(wifiOnly: true);
      expect(container.read(appSettingsProvider).syncWifiOnly, isTrue);
    });
  });

  group('SettingsScreen Widget Rendering Tests', () {
    testWidgets('SettingsScreen renders all sections cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top title
      expect(find.text('Settings'), findsOneWidget);

      // Section Titles
      expect(find.text('Appearance and Circadian Theme'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Daily Targets and Goals'), findsOneWidget);
      expect(find.text('Focus and Pomodoro'), findsOneWidget);
      expect(find.text('Movement and GPS Tracking'), findsOneWidget);
      expect(find.text('Finance and Currencies'), findsOneWidget);
      expect(find.text('Cloud Sync and SQLite Storage'), findsOneWidget);
      expect(find.text('Security and Privacy'), findsOneWidget);
      expect(find.text('About Cadence'), findsOneWidget);

      // Circadian Chips in Settings
      expect(find.text('Circadian'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      expect(find.text('Day (12:00)'), findsOneWidget);
      expect(find.text('Dusk (20:00)'), findsOneWidget);
      expect(find.text('Night (23:00)'), findsOneWidget);
    });
  });
}
