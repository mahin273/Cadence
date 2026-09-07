import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

/// Classification of an account as wealth asset vs debt liability.
enum AccountType {
  asset('asset', 'Asset', Icons.account_balance_rounded, Color(0xFF10B981)),
  liability('liability', 'Liability / Debt', Icons.credit_card_rounded, Color(0xFFF43F5E));

  final String id;
  final String label;
  final IconData defaultIcon;
  final Color color;

  const AccountType(this.id, this.label, this.defaultIcon, this.color);

  static AccountType fromString(String val) {
    if (val.toLowerCase() == 'liability') return AccountType.liability;
    return AccountType.asset;
  }
}

/// Detailed account classification subtype.
enum AccountSubType {
  checking('checking', 'Checking', Icons.account_balance_wallet_rounded),
  savings('savings', 'Savings', Icons.savings_rounded),
  investment('investment', 'Investment / Brokerage', Icons.trending_up_rounded),
  crypto('crypto', 'Cryptocurrency', Icons.currency_bitcoin_rounded),
  cash('cash', 'Physical Cash', Icons.payments_rounded),
  creditCard('credit_card', 'Credit Card', Icons.credit_card_rounded),
  loan('loan', 'Personal / Auto Loan', Icons.money_off_rounded),
  mortgage('mortgage', 'Mortgage / Property', Icons.home_work_rounded),
  other('other', 'Other', Icons.account_balance_rounded);

  final String id;
  final String label;
  final IconData icon;

  const AccountSubType(this.id, this.label, this.icon);

  static AccountSubType fromString(String val) {
    for (final st in AccountSubType.values) {
      if (st.id == val.toLowerCase()) return st;
    }
    return AccountSubType.other;
  }
}

/// Composite model linking an account with its most recent balance snapshot.
class AccountWithBalance {
  final Account account;
  final AccountBalance? latestBalance;

  const AccountWithBalance({
    required this.account,
    this.latestBalance,
  });

  /// Current balance in account (0.0 if never recorded).
  double get currentBalance => latestBalance?.balance ?? 0.0;

  /// Account type enum.
  AccountType get accountType => AccountType.fromString(account.type);

  /// SubType enum.
  AccountSubType get subType => AccountSubType.fromString(account.subType);

  /// Formatted date of last balance update.
  DateTime? get lastUpdated => latestBalance?.recordedAt;
}

/// Time-range filters for historical net worth chart.
enum NetWorthTimeRange {
  oneMonth('1M', Duration(days: 30)),
  threeMonths('3M', Duration(days: 90)),
  sixMonths('6M', Duration(days: 180)),
  oneYear('1Y', Duration(days: 365)),
  all('ALL', null);

  final String label;
  final Duration? duration;

  const NetWorthTimeRange(this.label, this.duration);
}

/// Point on historical net worth trajectory curve.
class NetWorthTimelinePoint {
  final DateTime date;
  final double netWorth;
  final double totalAssets;
  final double totalLiabilities;

  const NetWorthTimelinePoint({
    required this.date,
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
  });
}

/// Overall current net worth summary and account breakdown.
class NetWorthSummary {
  final double totalAssets;
  final double totalLiabilities;
  final double? previousNetWorth;
  final List<AccountWithBalance> assetAccounts;
  final List<AccountWithBalance> liabilityAccounts;

  const NetWorthSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    this.previousNetWorth,
    required this.assetAccounts,
    required this.liabilityAccounts,
  });

  /// Net Worth = Assets - Liabilities.
  double get netWorth => totalAssets - totalLiabilities;

  /// Absolute change from baseline/previous snapshot.
  double get netWorthChange =>
      previousNetWorth != null ? netWorth - previousNetWorth! : 0.0;

  /// Percentage change.
  double get netWorthChangePercentage {
    if (previousNetWorth == null || previousNetWorth! == 0.0) return 0.0;
    return (netWorthChange / previousNetWorth!.abs()) * 100;
  }

  /// Total count of active tracked accounts.
  int get accountCount => assetAccounts.length + liabilityAccounts.length;
}
