import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../models/net_worth_models.dart';

const _uuid = Uuid();

/// Stream of all active, non-archived accounts.
final activeAccountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchActiveAccounts();
});

/// Stream of all balance snapshot logs.
final allAccountBalancesStreamProvider =
    StreamProvider<List<AccountBalance>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllAccountBalances();
});

/// Combines active accounts with their most recent balance snapshot.
final accountsWithBalancesStreamProvider =
    Provider<AsyncValue<List<AccountWithBalance>>>((ref) {
  final accountsAsync = ref.watch(activeAccountsStreamProvider);
  final balancesAsync = ref.watch(allAccountBalancesStreamProvider);

  if (accountsAsync.isLoading || balancesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (accountsAsync.hasError) {
    return AsyncValue.error(accountsAsync.error!, accountsAsync.stackTrace!);
  }
  if (balancesAsync.hasError) {
    return AsyncValue.error(balancesAsync.error!, balancesAsync.stackTrace!);
  }

  final accounts = accountsAsync.value ?? [];
  final balances = balancesAsync.value ?? [];

  // Group latest balance by account ID (balances is ordered newest-first)
  final latestMap = <String, AccountBalance>{};
  for (final b in balances) {
    latestMap.putIfAbsent(b.accountId, () => b);
  }

  final list = accounts.map((acc) {
    return AccountWithBalance(
      account: acc,
      latestBalance: latestMap[acc.id],
    );
  }).toList();

  return AsyncValue.data(list);
});

/// Computes overall net worth summary (Assets, Liabilities, Net Worth).
final netWorthSummaryProvider = Provider<AsyncValue<NetWorthSummary>>((ref) {
  final accountsWithBalAsync = ref.watch(accountsWithBalancesStreamProvider);

  return accountsWithBalAsync.whenData((accounts) {
    double totalAssets = 0.0;
    double totalLiabilities = 0.0;
    final assetAccounts = <AccountWithBalance>[];
    final liabilityAccounts = <AccountWithBalance>[];

    for (final item in accounts) {
      if (item.accountType == AccountType.asset) {
        totalAssets += item.currentBalance;
        assetAccounts.add(item);
      } else {
        totalLiabilities += item.currentBalance;
        liabilityAccounts.add(item);
      }
    }

    return NetWorthSummary(
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      assetAccounts: assetAccounts,
      liabilityAccounts: liabilityAccounts,
    );
  });
});

/// Currently selected time filter range for the net worth chart.
class NetWorthRangeNotifier extends Notifier<NetWorthTimeRange> {
  @override
  NetWorthTimeRange build() => NetWorthTimeRange.threeMonths;

  void setRange(NetWorthTimeRange range) {
    state = range;
  }
}

final netWorthRangeProvider =
    NotifierProvider<NetWorthRangeNotifier, NetWorthTimeRange>(
  NetWorthRangeNotifier.new,
);

/// Computes historical trajectory points for charting over the selected range.
final netWorthTimelinePointsProvider =
    Provider<List<NetWorthTimelinePoint>>((ref) {
  final accounts = ref.watch(activeAccountsStreamProvider).value ?? [];
  final balances = ref.watch(allAccountBalancesStreamProvider).value ?? [];
  final range = ref.watch(netWorthRangeProvider);

  if (accounts.isEmpty || balances.isEmpty) {
    return [];
  }

  final now = DateTime.now();
  final cutoffDate =
      range.duration != null ? now.subtract(range.duration!) : null;

  // Filter balances within cutoff range
  final filteredBalances = cutoffDate != null
      ? balances.where((b) => b.recordedAt.isAfter(cutoffDate)).toList()
      : balances;

  if (filteredBalances.isEmpty) {
    // If no balances in cutoff, use current latest point
    return [];
  }

  // Collect unique sorted calendar dates of all recorded balances
  final dateSet = <DateTime>{};
  for (final b in filteredBalances) {
    dateSet.add(DateTime(b.recordedAt.year, b.recordedAt.month, b.recordedAt.day));
  }
  // Add today's date
  dateSet.add(DateTime(now.year, now.month, now.day));
  final sortedDates = dateSet.toList()..sort();

  // For each date, find the most recent balance for each account on or before that date
  final points = <NetWorthTimelinePoint>[];

  for (final d in sortedDates) {
    final endOfDay = DateTime(d.year, d.month, d.day, 23, 59, 59);
    double dayAssets = 0.0;
    double dayLiabilities = 0.0;

    for (final acc in accounts) {
      // Find latest balance for this account on or before endOfDay
      final relevantBalances = balances
          .where((b) => b.accountId == acc.id && b.recordedAt.isBefore(endOfDay))
          .toList()
        ..sort((a, b) {
          final cmp = b.recordedAt.compareTo(a.recordedAt);
          if (cmp != 0) return cmp;
          return b.createdAt.compareTo(a.createdAt);
        });

      final balance =
          relevantBalances.isNotEmpty ? relevantBalances.first.balance : 0.0;

      if (acc.type.toLowerCase() == 'asset') {
        dayAssets += balance;
      } else {
        dayLiabilities += balance;
      }
    }

    points.add(
      NetWorthTimelinePoint(
        date: d,
        netWorth: dayAssets - dayLiabilities,
        totalAssets: dayAssets,
        totalLiabilities: dayLiabilities,
      ),
    );
  }

  return points;
});

/// Controller handling account creation, updates, and balance snapshot insertions.
class NetWorthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<String?> createAccount({
    required String name,
    required AccountType type,
    required AccountSubType subType,
    String currency = 'USD',
    int colorValue = 0xFF10B981,
    String iconName = 'account_balance_rounded',
    double? initialBalance,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final userId = ref.read(activeUserIdProvider);
      final accountId = _uuid.v4();

      final companion = AccountsCompanion(
        id: drift.Value(accountId),
        userId: drift.Value(userId),
        name: drift.Value(name),
        type: drift.Value(type.id),
        subType: drift.Value(subType.id),
        currency: drift.Value(currency),
        colorValue: drift.Value(colorValue),
        iconName: drift.Value(iconName),
        isArchived: const drift.Value(false),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      );

      await db.upsertAccount(companion);

      if (initialBalance != null) {
        await recordBalance(
          accountId: accountId,
          balance: initialBalance,
          note: 'Initial balance',
        );
      }

      state = const AsyncValue.data(null);
      return accountId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> recordBalance({
    required String accountId,
    required double balance,
    DateTime? recordedAt,
    String? note,
  }) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final balanceId = _uuid.v4();

      final companion = AccountBalancesCompanion(
        id: drift.Value(balanceId),
        accountId: drift.Value(accountId),
        balance: drift.Value(balance),
        recordedAt: drift.Value(recordedAt ?? DateTime.now()),
        note: drift.Value(note),
        createdAt: drift.Value(DateTime.now()),
      );

      await db.insertAccountBalance(companion);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.deleteAccount(accountId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteBalance(String balanceId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.deleteAccountBalance(balanceId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final netWorthControllerProvider =
    NotifierProvider<NetWorthController, AsyncValue<void>>(
  NetWorthController.new,
);
