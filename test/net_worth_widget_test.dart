import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/finance/models/net_worth_models.dart';
import 'package:cadence/features/finance/presentation/net_worth_view.dart';
import 'package:cadence/features/finance/providers/net_worth_provider.dart';
import 'package:cadence/features/finance/widgets/net_worth_chart.dart';
import 'package:cadence/features/finance/widgets/net_worth_overview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Net Worth UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('NetWorthOverviewCard renders net worth, assets, debts, and navigates to NetWorthView on tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          netWorthSummaryProvider.overrideWithValue(
            const AsyncValue.data(
              NetWorthSummary(
                totalAssets: 50000.0,
                totalLiabilities: 15000.0,
                assetAccounts: [],
                liabilityAccounts: [],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NetWorthOverviewCard()),
          ),
        ),
      );

      expect(find.text('Total Net Worth'), findsOneWidget);
      expect(find.text('\$35,000.00'), findsOneWidget);
      expect(find.text('Total Assets'), findsOneWidget);
      expect(find.text('\$50,000.00'), findsOneWidget);
      expect(find.text('Total Debt'), findsOneWidget);
      expect(find.text('\$15,000.00'), findsOneWidget);

      // Tap card to navigate to NetWorthView
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      expect(find.byType(NetWorthView), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('NetWorthChart renders time range chips and switches filter', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NetWorthChart()),
          ),
        ),
      );

      expect(find.text('Net Worth Trajectory'), findsOneWidget);
      expect(find.text('1M'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('1Y'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);

      // Tap '1Y' filter
      await tester.tap(find.text('1Y'));
      await tester.pump();

      expect(container.read(netWorthRangeProvider), NetWorthTimeRange.oneYear);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('NetWorthView creates account and updates balance snapshot', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeUserIdProvider.overrideWith((ref) => 'test-user'),
          ],
          child: const MaterialApp(
            home: NetWorthView(),
          ),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      expect(find.text('Net Worth & Accounts'), findsOneWidget);

      // Open Add Account dialog via FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Account Name'), findsOneWidget);

      // Fill in Account details
      final nameField = find.widgetWithText(TextField, 'Account Name');
      await tester.enterText(nameField, 'Fidelity Roth IRA');

      final balanceField = find.widgetWithText(TextField, 'Current Balance (\$)');
      await tester.enterText(balanceField, '14500.00');

      // Submit Create Account
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify new account appears in Assets list
      await tester.scrollUntilVisible(find.text('Fidelity Roth IRA'), 200);
      expect(find.text('Fidelity Roth IRA'), findsOneWidget);
      expect(find.text('\$14,500.00'), findsWidgets);

      // Tap 'Update' on the account tile to record a new balance snapshot
      final updateBtn = find.widgetWithText(TextButton, 'Update');
      await tester.scrollUntilVisible(updateBtn, 100);
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Update Fidelity Roth IRA'), findsOneWidget);

      // Enter new balance $16,200.00
      final updateField = find.widgetWithText(TextField, 'Current Balance');
      await tester.enterText(updateField, '16200.00');

      await tester.tap(find.widgetWithText(FilledButton, 'Save Snapshot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('\$16,200.00'), findsWidgets);

      // Verify SQLite state directly
      final accounts = await db.getActiveAccounts();
      expect(accounts.length, 1);
      final latestBal = await db.getLatestBalanceForAccount(accounts.first.id);
      expect(latestBal!.balance, 16200.0);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
