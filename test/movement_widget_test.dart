import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/movement/presentation/movement_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-movement-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Movement UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('MovementView renders step gauge, metric cards and quick actions', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const MovementView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Movement'), findsOneWidget);
      expect(find.text('Goal: 10,000'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Active Burn'), findsOneWidget);
      expect(find.text('Cadence'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('+1,000'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Connected to Daily Goals'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping +500 quick log persists step entry to Drift DB and updates UI', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const MovementView(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap +500
      await tester.ensureVisible(find.text('+500'));
      await tester.tap(find.text('+500'));
      await tester.pumpAndSettle();

      // Verify UI reflects 500 steps
      expect(find.text('500'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);

      // Verify row in Drift entries table
      final entries = await (db.select(db.entries)..where((tbl) => tbl.type.equals('steps'))).get();
      expect(entries.length, 1);
      expect(entries.first.value, 500.0);
      expect(entries.first.unit, 'steps');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Custom step dialog logs custom walk and notes to DB', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const MovementView(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Custom button
      await tester.ensureVisible(find.text('Custom'));
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('Log Steps Manually'), findsOneWidget);

      // Enter 2,500 steps and notes
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '2500');
      await tester.enterText(textFields.last, 'Evening park stroll');
      await tester.pumpAndSettle();

      // Tap Log Steps submit button
      await tester.tap(find.text('Log Steps'));
      await tester.pumpAndSettle();

      // Verify row in Drift DB
      final entries = await (db.select(db.entries)..where((tbl) => tbl.type.equals('steps'))).get();
      expect(entries.length, 1);
      expect(entries.first.value, 2500.0);
      expect(entries.first.note, 'Evening park stroll');

      // Verify UI reflects 2,500 steps
      expect(find.text('2,500'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
