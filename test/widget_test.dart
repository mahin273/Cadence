import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/app.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/database/connection/native_connection.dart';

void main() {
  testWidgets('CadenceApp boots and renders circadian dashboard with navigation and reactive Drift DB', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final inMemoryDb = AppDatabase(openInMemoryConnection());
    addTearDown(() async => inMemoryDb.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify App Bar
    expect(find.text('Cadence'), findsOneWidget);

    // Verify Navigation destinations
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Movement'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);

    // Verify Circadian preview controls are present
    expect(find.text('Preview Circadian Shifts (Color.lerp)'), findsOneWidget);
    expect(find.text('Day (12:00)'), findsOneWidget);
    expect(find.text('Dusk (20:00)'), findsOneWidget);
    expect(find.text('Night (23:00)'), findsOneWidget);

    // Verify Drift SQLite status card initially has 0 entries
    expect(find.text('Local SQLite (Drift)'), findsOneWidget);
    expect(find.text('0 entries'), findsOneWidget);

    // Tap quick water log button
    final quickAddButton = find.text('Log Quick Water Entry');
    expect(quickAddButton, findsOneWidget);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();

    // Verify reactive stream update: counter increments to 1
    expect(find.text('1 entries'), findsOneWidget);

    // Tap Dusk preview chip
    await tester.tap(find.text('Dusk (20:00)'));
    await tester.pumpAndSettle();

    // Verify transition to Dusk phase
    expect(find.text('Warm Dusk Transition'), findsOneWidget);

    // Tap account icon to open AuthModal
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();

    // Verify AuthModal is displayed with offline guest options
    expect(find.text('Supabase Cloud Account'), findsOneWidget);
    expect(find.text('Continue in Offline Guest Mode'), findsOneWidget);

    // Tap continue as guest to dismiss
    await tester.tap(find.text('Continue in Offline Guest Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Supabase Cloud Account'), findsNothing);

    // Verify Activity Feed section and filter chips (scroll past the
    // Chunk 24 hero greeting + vitals header first).
    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Today's Activity Feed"), findsOneWidget);
    expect(find.text('All Activity'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);

    // Tap FloatingActionButton Quick Add (Chunk 24 command palette)
    final fab = find.widgetWithText(FloatingActionButton, 'Quick Add');
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify GlobalQuickAddModal appears with 6 rapid actions
    expect(find.text('Thought / Habit'), findsOneWidget);
    expect(find.text('Log Expense'), findsOneWidget);

    // Dispatch the Thought / Habit action into the legacy QuickLogModal.
    // (Bounded pumps: the palette pop + modal push overlap animations that
    // pumpAndSettle can wait on indefinitely.)
    await tester.tap(find.text('Thought / Habit'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify QuickLogModal appears
    expect(find.text('Quick Log Entry'), findsOneWidget);

    // Select Habit segment
    await tester.tap(find.text('Habit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Enter habit title
    await tester.enterText(find.byType(TextField).first, 'Read 20 pages');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Save Entry
    await tester.tap(find.text('Save Entry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify modal is dismissed and new habit entry appears in feed
    expect(find.text('Quick Log Entry'), findsNothing);
    expect(find.text('Read 20 pages'), findsOneWidget);

    // Unmount widget tree and advance timers to flush Drift StreamQueryStore cleanup timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
