import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/features/finance/models/debt_models.dart';
import 'package:cadence/features/finance/providers/debt_provider.dart';

void main() {
  group('Debt Models & Summary Formulas', () {
    test('DebtLedgerSummary calculates Total Lent, Total Borrowed and Net Balance', () {
      final summary = DebtLedgerSummary(
        totalLent: 350.0,
        totalBorrowed: 150.0,
        netBalance: 200.0,
        activeLentCount: 2,
        activeBorrowedCount: 1,
        settledCount: 3,
      );

      expect(summary.totalLent, 350.0);
      expect(summary.totalBorrowed, 150.0);
      expect(summary.netBalance, 200.0);
      expect(summary.isPositive, isTrue);
      expect(summary.activeLentCount, 2);
      expect(summary.activeBorrowedCount, 1);
      expect(summary.settledCount, 3);
    });

    test('DebtLedgerSummary correctly identifies negative peer net balance', () {
      final summary = DebtLedgerSummary(
        totalLent: 50.0,
        totalBorrowed: 300.0,
        netBalance: -250.0,
        activeLentCount: 1,
        activeBorrowedCount: 2,
        settledCount: 0,
      );

      expect(summary.netBalance, -250.0);
      expect(summary.isPositive, isFalse);
    });

    test('DebtWithPayments computes progress and overdue status correctly', () {
      final now = DateTime.now();
      final activeDebt = Debt(
        id: 'debt-1',
        userId: 'user-1',
        personName: 'Bob',
        type: 'lent',
        initialAmount: 200.0,
        remainingAmount: 50.0,
        dueDate: now.subtract(const Duration(days: 3)),
        notes: 'Lunch and groceries',
        isSettled: false,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
        isSynced: false,
      );

      final withPayments = DebtWithPayments(debt: activeDebt);
      expect(withPayments.paidAmount, 150.0);
      expect(withPayments.progress, 0.75);
      expect(withPayments.isSettled, isFalse);
      expect(withPayments.isOverdue, isTrue);
    });
  });

  group('Debt Database Operations & Controller', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('createDebt inserts into SQLite and initializes active state', () async {
      final controller = container.read(debtControllerProvider.notifier);

      final debtId = await controller.createDebt(
        personName: 'Alice Smith',
        type: DebtType.lent,
        initialAmount: 250.0,
        dueDate: DateTime.now().add(const Duration(days: 14)),
        notes: 'Concert ticket',
      );

      expect(debtId, isNotNull);

      final fetched = await db.getDebtById(debtId!);
      expect(fetched, isNotNull);
      expect(fetched!.personName, 'Alice Smith');
      expect(fetched.type, 'lent');
      expect(fetched.initialAmount, 250.0);
      expect(fetched.remainingAmount, 250.0);
      expect(fetched.isSettled, isFalse);
      expect(fetched.notes, 'Concert ticket');
    });

    test('recordPayment partially decrements remaining balance atomically', () async {
      final controller = container.read(debtControllerProvider.notifier);

      final debtId = await controller.createDebt(
        personName: 'Charlie',
        type: DebtType.borrowed,
        initialAmount: 300.0,
      );

      final success = await controller.recordPayment(
        debtId: debtId!,
        amount: 100.0,
        notes: 'First installment via Venmo',
      );

      expect(success, isTrue);

      final updated = await db.getDebtById(debtId);
      expect(updated!.remainingAmount, 200.0);
      expect(updated.isSettled, isFalse);

      final payments = await db.getPaymentsForDebt(debtId);
      expect(payments.length, 1);
      expect(payments.first.amount, 100.0);
      expect(payments.first.notes, 'First installment via Venmo');
    });

    test('recordPayment full settlement transitions isSettled to true', () async {
      final controller = container.read(debtControllerProvider.notifier);

      final debtId = await controller.createDebt(
        personName: 'David',
        type: DebtType.lent,
        initialAmount: 80.0,
      );

      // Pay full remaining amount
      final success = await controller.recordPayment(
        debtId: debtId!,
        amount: 80.0,
        notes: 'Cash in full',
      );

      expect(success, isTrue);

      final updated = await db.getDebtById(debtId);
      expect(updated!.remainingAmount, 0.0);
      expect(updated.isSettled, isTrue);
    });

    test('toggleSettled manually modifies settlement status', () async {
      final controller = container.read(debtControllerProvider.notifier);

      final debtId = await controller.createDebt(
        personName: 'Eva',
        type: DebtType.lent,
        initialAmount: 150.0,
      );

      await controller.toggleSettled(debtId: debtId!, isSettled: true);
      var fetched = await db.getDebtById(debtId);
      expect(fetched!.isSettled, isTrue);

      await controller.toggleSettled(debtId: debtId, isSettled: false);
      fetched = await db.getDebtById(debtId);
      expect(fetched!.isSettled, isFalse);
    });

    test('deleteDebt cascades deletion to child payment records', () async {
      final controller = container.read(debtControllerProvider.notifier);

      final debtId = await controller.createDebt(
        personName: 'Frank',
        type: DebtType.borrowed,
        initialAmount: 500.0,
      );

      await controller.recordPayment(
        debtId: debtId!,
        amount: 50.0,
      );

      var payments = await db.getPaymentsForDebt(debtId);
      expect(payments.length, 1);

      await controller.deleteDebt(debtId);

      final fetchedDebt = await db.getDebtById(debtId);
      expect(fetchedDebt, isNull);

      payments = await db.getPaymentsForDebt(debtId);
      expect(payments, isEmpty);
    });
  });
}
