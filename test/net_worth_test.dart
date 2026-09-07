import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/finance/models/net_worth_models.dart';
import 'package:cadence/features/finance/providers/net_worth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetWorthSummary Formulas & Logic', () {
    test('calculates Net Worth = Assets - Liabilities accurately', () {
      final summary = NetWorthSummary(
        totalAssets: 45000.0,
        totalLiabilities: 12000.0,
        previousNetWorth: 30000.0,
        assetAccounts: [],
        liabilityAccounts: [],
      );

      expect(summary.netWorth, 33000.0);
      expect(summary.netWorthChange, 3000.0);
      expect(summary.netWorthChangePercentage, closeTo(10.0, 0.01));
    });

    test('handles negative net worth when debts exceed assets', () {
      final summary = NetWorthSummary(
        totalAssets: 5000.0,
        totalLiabilities: 18000.0,
        assetAccounts: [],
        liabilityAccounts: [],
      );

      expect(summary.netWorth, -13000.0);
    });
  });

  group('NetWorth Database Operations & Controller', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'user-networth-test'),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('createAccount, recordBalance, and query latest balances', () async {
      final controller = container.read(netWorthControllerProvider.notifier);

      // 1. Create Checking account with initial balance $3,000
      final checkingId = await controller.createAccount(
        name: 'Main Checking',
        type: AccountType.asset,
        subType: AccountSubType.checking,
        initialBalance: 3000.0,
      );
      expect(checkingId, isNotNull);

      // 2. Create Credit Card account with initial balance $800
      final cardId = await controller.createAccount(
        name: 'Sapphire Card',
        type: AccountType.liability,
        subType: AccountSubType.creditCard,
        initialBalance: 800.0,
      );
      expect(cardId, isNotNull);

      // Verify accounts in DB
      final accounts = await db.getActiveAccounts();
      expect(accounts.length, 2);

      // Verify latest balance query
      final checkingBal = await db.getLatestBalanceForAccount(checkingId!);
      expect(checkingBal, isNotNull);
      expect(checkingBal!.balance, 3000.0);

      // 3. Record updated balance for checking after paycheck ($5,500)
      final laterDate = DateTime.now().add(const Duration(days: 7));
      await controller.recordBalance(
        accountId: checkingId,
        balance: 5500.0,
        recordedAt: laterDate,
        note: 'Bi-weekly paycheck',
      );

      final updatedBal = await db.getLatestBalanceForAccount(checkingId);
      expect(updatedBal!.balance, 5500.0);
      expect(updatedBal.note, 'Bi-weekly paycheck');

      // Balance history should have 2 records for checking
      final history = await db.watchBalancesForAccount(checkingId).first;
      expect(history.length, 2);
    });

    test('cascade deletion removes child balances when account is deleted', () async {
      final controller = container.read(netWorthControllerProvider.notifier);

      final accId = await controller.createAccount(
        name: 'High Yield Savings',
        type: AccountType.asset,
        subType: AccountSubType.savings,
        initialBalance: 10000.0,
      );

      var balances = await db.watchBalancesForAccount(accId!).first;
      expect(balances.length, 1);

      // Delete account
      await controller.deleteAccount(accId);

      final accounts = await db.getActiveAccounts();
      expect(accounts.isEmpty, isTrue);

      balances = await db.watchBalancesForAccount(accId).first;
      expect(balances.isEmpty, isTrue);
    });

    test('netWorthTimelinePointsProvider computes trajectory points over time', () async {
      final controller = container.read(netWorthControllerProvider.notifier);

      final baseDate = DateTime(2026, 6, 1);
      final accId = await controller.createAccount(
        name: 'Investment',
        type: AccountType.asset,
        subType: AccountSubType.investment,
      );

      // Record snapshot 1
      await controller.recordBalance(
        accountId: accId!,
        balance: 10000.0,
        recordedAt: baseDate,
      );

      // Record snapshot 2
      await controller.recordBalance(
        accountId: accId,
        balance: 12500.0,
        recordedAt: baseDate.add(const Duration(days: 15)),
      );

      // Set time range to ALL so points are included
      container
          .read(netWorthRangeProvider.notifier)
          .setRange(NetWorthTimeRange.all);

      // Listen to stream providers to activate subscriptions
      final sub1 = container.listen(activeAccountsStreamProvider, (_, _) {});
      final sub2 = container.listen(allAccountBalancesStreamProvider, (_, _) {});
      await pumpEventQueue();

      final points = container.read(netWorthTimelinePointsProvider);
      expect(points, isNotEmpty);
      expect(points.first.netWorth, 10000.0);

      sub1.close();
      sub2.close();
    });
  });
}
