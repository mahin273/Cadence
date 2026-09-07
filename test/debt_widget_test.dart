import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/finance/widgets/debt_overview_card.dart';
import 'package:cadence/features/finance/presentation/debt_ledger_view.dart';

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
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Debt UI Widgets', () {
    testWidgets('DebtOverviewCard renders metrics and navigates to DebtLedgerView',
        (tester) async {
      final now = DateTime.now();

      // Seed 1 lent and 1 borrowed debt
      await db.upsertDebt(
        DebtsCompanion.insert(
          id: 'seed-1',
          personName: 'Alex',
          type: 'lent',
          initialAmount: 300.0,
          remainingAmount: 200.0,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.upsertDebt(
        DebtsCompanion.insert(
          id: 'seed-2',
          personName: 'Ben',
          type: 'borrowed',
          initialAmount: 100.0,
          remainingAmount: 50.0,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(createTestWidget(const Scaffold(body: DebtOverviewCard())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Debt & Lending Ledger'), findsOneWidget);
      expect(find.text('Owed to You'), findsOneWidget);
      expect(find.text('\$200.00'), findsOneWidget);
      expect(find.text('You Owe'), findsOneWidget);
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('Net Balance'), findsOneWidget);
      expect(find.text('+\$150.00'), findsOneWidget);

      // Tap card to navigate
      await tester.tap(find.byType(DebtOverviewCard));
      await tester.pumpAndSettle();

      expect(find.byType(DebtLedgerView), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('DebtLedgerView switches tabs and filters by debt direction',
        (tester) async {
      final now = DateTime.now();

      await db.upsertDebt(
        DebtsCompanion.insert(
          id: 'd-active-lent',
          personName: 'Charlie Lent',
          type: 'lent',
          initialAmount: 150.0,
          remainingAmount: 150.0,
          isSettled: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.upsertDebt(
        DebtsCompanion.insert(
          id: 'd-settled-borrowed',
          personName: 'Diana Settled',
          type: 'borrowed',
          initialAmount: 80.0,
          remainingAmount: 0.0,
          isSettled: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(createTestWidget(const DebtLedgerView()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Active tab shows Charlie, does not show Diana
      expect(find.text('Charlie Lent'), findsOneWidget);
      expect(find.text('Diana Settled'), findsNothing);

      // Switch to Settled tab
      await tester.tap(find.text('Settled'));
      await tester.pumpAndSettle();

      expect(find.text('Diana Settled'), findsOneWidget);
      expect(find.text('Charlie Lent'), findsNothing);

      // Switch back to Active tab
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      // Filter by 'I Owe (Borrowed)' -> Charlie is lent, so list becomes empty
      await tester.tap(find.text('I Owe (Borrowed)'));
      await tester.pumpAndSettle();

      expect(find.text('Charlie Lent'), findsNothing);
      expect(find.text('No active debts found'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('DebtLedgerView creates debt and records partial repayment',
        (tester) async {
      await tester.pumpWidget(createTestWidget(const DebtLedgerView()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Create Debt Dialog
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Entry'));
      await tester.pumpAndSettle();

      expect(find.text('New Debt / Loan Entry'), findsOneWidget);

      // Fill in debt details
      final nameField = find.widgetWithText(TextField, 'Person / Entity Name');
      await tester.enterText(nameField, 'Sarah Connor');

      final amountField = find.widgetWithText(TextField, 'Total Amount');
      await tester.enterText(amountField, '120.00');

      await tester.tap(find.widgetWithText(FilledButton, 'Save Entry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify Sarah Connor appears in the list
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('\$120.00'), findsWidgets);

      // Record a partial payment of $40.00
      final payBtn = find.widgetWithText(OutlinedButton, 'Record Payment');
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      expect(find.text('Record Payment: Sarah Connor'), findsOneWidget);

      final payAmountField = find.widgetWithText(TextField, 'Payment Amount');
      await tester.enterText(payAmountField, '40.00');

      await tester.tap(find.widgetWithText(FilledButton, 'Save Payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify remaining balance changed to $80.00 (in summary card and debt card)
      expect(find.text('\$80.00'), findsWidgets);

      // Verify in SQLite directly
      final debts = await db.getActiveDebts();
      expect(debts.length, 1);
      expect(debts.first.remainingAmount, 80.0);
      expect(debts.first.isSettled, isFalse);

      final payments = await db.getPaymentsForDebt(debts.first.id);
      expect(payments.length, 1);
      expect(payments.first.amount, 40.0);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
