import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/analytics/services/screen_time_platform_service.dart';
import 'package:cadence/features/analytics/providers/screen_time_provider.dart';
import 'package:cadence/features/analytics/widgets/screen_time_card.dart';
import 'package:cadence/features/analytics/presentation/screen_time_view.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        screenTimeServiceProvider.overrideWithValue(
          const ScreenTimePlatformService(forceMock: true),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('ScreenTime UI Widgets', () {
    testWidgets('ScreenTimeCard renders on dashboard and navigates to ScreenTimeView',
        (tester) async {
      await tester.pumpWidget(createTestWidget(const Scaffold(body: ScreenTimeCard())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Screen Time & Wellbeing'), findsOneWidget);

      // Tap Sync button on the card to populate today's screen time
      final syncBtn = find.widgetWithText(TextButton, 'Sync');
      expect(syncBtn, findsOneWidget);
      await tester.tap(syncBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify populated total
      expect(find.text('3h 20m'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);

      // Tap card to navigate to full view
      await tester.tap(find.byType(ScreenTimeCard));
      await tester.pumpAndSettle();

      expect(find.byType(ScreenTimeView), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ScreenTimeView displays hero summary, category distribution and top apps',
        (tester) async {
      await tester.pumpWidget(createTestWidget(const ScreenTimeView()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initial empty state has 'Sync Device Screen Time' button
      final initialSyncBtn = find.text('Sync Device Screen Time');
      expect(initialSyncBtn, findsOneWidget);

      await tester.tap(initialSyncBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify total screen time hero text
      expect(find.text('Total Screen Time'), findsOneWidget);
      expect(find.text('3h 20m'), findsOneWidget);
      expect(find.text('Most used: Entertainment'), findsOneWidget);

      // Verify top apps listed
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Notion'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Instagram'), 200);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Google Chrome'), findsOneWidget);

      // Scroll back up to date bar and navigate to previous day
      await tester.scrollUntilVisible(
        find.byIcon(Icons.chevron_left_rounded),
        -200,
      );
      final prevBtn = find.byIcon(Icons.chevron_left_rounded);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      // Previous day has no records yet
      expect(find.text('No screen time recorded for this date'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
