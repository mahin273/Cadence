import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/features/notifications/services/circadian_notification_service.dart';
import 'package:cadence/features/notifications/presentation/circadian_nudges_settings_view.dart';
import 'package:cadence/features/settings/presentation/settings_screen.dart';

void main() {
  late AppDatabase db;
  late CircadianNotificationService service;

  setUp(() {
    db = AppDatabase(openInMemoryConnection());
    service = CircadianNotificationService(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CircadianNotificationService Unit Tests', () {
    test('calculateHydrationPace computes expected intake and deficit across daylight hours', () {
      // 07:00 (Pre-dawn/Early morning): 0 expected, not behind
      final pace7 = service.calculateHydrationPace(
        currentGlasses: 0,
        currentHour: 7,
        targetGlasses: 8,
      );
      expect(pace7.isBehind, isFalse);
      expect(pace7.expectedGlasses, 0.0);

      // 12:00 (Noon, 5 hours passed from 8:00): expected ~ 3.1 glasses
      // If user has drank 3.5 glasses, they are ON PACE
      final paceNoonGood = service.calculateHydrationPace(
        currentGlasses: 3.5,
        currentHour: 12,
        targetGlasses: 8,
      );
      expect(paceNoonGood.isBehind, isFalse);

      // If user has drank 1 glass at noon, they are BEHIND
      final paceNoonBehind = service.calculateHydrationPace(
        currentGlasses: 1.0,
        currentHour: 12,
        targetGlasses: 8,
      );
      expect(paceNoonBehind.isBehind, isTrue);
      expect(paceNoonBehind.deficit, greaterThanOrEqualTo(1.0));

      // 20:00 (Evening / 8 PM): full 8 glasses expected
      final paceEveningFull = service.calculateHydrationPace(
        currentGlasses: 8.0,
        currentHour: 20,
        targetGlasses: 8,
      );
      expect(paceEveningFull.isBehind, isFalse);
      expect(paceEveningFull.deficit, 0.0);

      final paceEveningBehind = service.calculateHydrationPace(
        currentGlasses: 4.0,
        currentHour: 20,
        targetGlasses: 8,
      );
      expect(paceEveningBehind.isBehind, isTrue);
      expect(paceEveningBehind.deficit, 4.0);
    });

    test('checkAndTriggerPacedHydrationNudge consults SQLite and only alerts on deficit', () async {
      final afternoonTime = DateTime(2026, 4, 15, 15, 0); // 3 PM

      // Case A: Fresh DB (0 glasses recorded) -> deficit detected, triggers nudge
      final triggeredWhenEmpty = await service.checkAndTriggerPacedHydrationNudge(
        now: afternoonTime,
        targetGlasses: 8,
      );
      expect(triggeredWhenEmpty, isTrue);

      // Case B: User logs 6 glasses in SQLite -> on pace, suppresses nudge
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'w_paced',
              userId: 'u1',
              type: 'water',
              value: 6.0,
              occurredAt: afternoonTime.subtract(const Duration(hours: 1)),
            ),
          );

      final triggeredWhenLogged = await service.checkAndTriggerPacedHydrationNudge(
        now: afternoonTime,
        targetGlasses: 8,
      );
      expect(triggeredWhenLogged, isFalse);
    });
  });

  group('Circadian Nudges Widget Tests', () {
    testWidgets('CircadianNudgesSettingsView renders toggles and diagnostic actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: CircadianNudgesSettingsView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Circadian Nudges & Alerts'), findsOneWidget);
      expect(find.text('Biologically Paced, Never Spammed'), findsOneWidget);
      expect(find.text('Enable Circadian Nudges'), findsOneWidget);
      expect(find.text('Paced Hydration Nudge'), findsOneWidget);
      expect(find.text('Circadian Phase Shifts'), findsOneWidget);
      expect(find.text('Deep Work Recovery'), findsOneWidget);
      expect(find.text('Send Test Circadian Notification'), findsOneWidget);
      expect(find.text('Simulate Paced Hydration Check'), findsOneWidget);
    });

    testWidgets('SettingsScreen has entry for Circadian Nudges & Notifications', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Circadian Nudges & Notifications'), findsOneWidget);
      expect(find.text('Paced hydration, phase shifts & focus recovery'), findsOneWidget);
    });
  });
}
