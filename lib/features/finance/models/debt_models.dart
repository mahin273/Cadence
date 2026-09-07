import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

/// Classifies interpersonal debt direction.
enum DebtType {
  lent('lent', 'Lent (Owed to me)'),
  borrowed('borrowed', 'Borrowed (I owe)');

  final String id;
  final String label;
  const DebtType(this.id, this.label);

  static DebtType fromId(String id) {
    return DebtType.values.firstWhere(
      (t) => t.id.toLowerCase() == id.toLowerCase(),
      orElse: () => DebtType.lent,
    );
  }

  Color get color {
    switch (this) {
      case DebtType.lent:
        return Colors.green;
      case DebtType.borrowed:
        return Colors.redAccent;
    }
  }

  IconData get icon {
    switch (this) {
      case DebtType.lent:
        return Icons.call_made_rounded;
      case DebtType.borrowed:
        return Icons.call_received_rounded;
    }
  }
}

/// Combines a Debt entity with its historical repayment child records.
class DebtWithPayments {
  final Debt debt;
  final List<DebtPayment> payments;

  const DebtWithPayments({
    required this.debt,
    this.payments = const [],
  });

  DebtType get debtType => DebtType.fromId(debt.type);

  double get initialAmount => debt.initialAmount;
  double get remainingAmount => debt.remainingAmount;
  double get paidAmount =>
      (debt.initialAmount - debt.remainingAmount).clamp(0.0, double.infinity);

  double get progress => debt.initialAmount > 0
      ? (paidAmount / debt.initialAmount).clamp(0.0, 1.0)
      : 0.0;

  bool get isSettled => debt.isSettled;

  bool get isOverdue {
    if (isSettled || debt.dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.isAfter(debt.dueDate!);
  }
}

/// Aggregated peer balance summary metrics.
class DebtLedgerSummary {
  final double totalLent;
  final double totalBorrowed;
  final double netBalance;
  final int activeLentCount;
  final int activeBorrowedCount;
  final int settledCount;

  const DebtLedgerSummary({
    this.totalLent = 0.0,
    this.totalBorrowed = 0.0,
    this.netBalance = 0.0,
    this.activeLentCount = 0,
    this.activeBorrowedCount = 0,
    this.settledCount = 0,
  });

  bool get isPositive => netBalance >= 0;
}
