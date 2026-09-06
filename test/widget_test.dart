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
  });
}
