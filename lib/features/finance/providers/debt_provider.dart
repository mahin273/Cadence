import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../models/debt_models.dart';

const _uuid = Uuid();

/// Filter tabs for debt ledger view.
enum DebtTabFilter { active, settled }

/// Filter types for debt list.
enum DebtTypeFilter { all, lent, borrowed }

/// Currently selected debt tab filter (active vs settled).
class DebtTabFilterNotifier extends Notifier<DebtTabFilter> {
  @override
  DebtTabFilter build() => DebtTabFilter.active;

  void setFilter(DebtTabFilter filter) => state = filter;
}

final debtTabFilterProvider =
    NotifierProvider<DebtTabFilterNotifier, DebtTabFilter>(
  DebtTabFilterNotifier.new,
);

/// Currently selected debt type filter (all, lent, borrowed).
class DebtTypeFilterNotifier extends Notifier<DebtTypeFilter> {
  @override
  DebtTypeFilter build() => DebtTypeFilter.all;

  void setFilter(DebtTypeFilter filter) => state = filter;
}

final debtTypeFilterProvider =
    NotifierProvider<DebtTypeFilterNotifier, DebtTypeFilter>(
  DebtTypeFilterNotifier.new,
);

/// Reactive stream of all debts ordered by isSettled ASC, createdAt DESC, rowId DESC.
final allDebtsStreamProvider = StreamProvider<List<Debt>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllDebts();
});

/// Reactive stream of payments for a given debt.
final debtPaymentsStreamProvider =
    StreamProvider.family<List<DebtPayment>, String>((ref, debtId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPaymentsForDebt(debtId);
});

/// Summary calculation across all debts.
final debtLedgerSummaryProvider = Provider<AsyncValue<DebtLedgerSummary>>((ref) {
  final debtsAsync = ref.watch(allDebtsStreamProvider);

  return debtsAsync.whenData((debts) {
    double totalLent = 0.0;
    double totalBorrowed = 0.0;
    int activeLentCount = 0;
    int activeBorrowedCount = 0;
    int settledCount = 0;

    for (final d in debts) {
      if (d.isSettled) {
        settledCount++;
      } else {
        final type = DebtType.fromId(d.type);
        if (type == DebtType.lent) {
          totalLent += d.remainingAmount;
          activeLentCount++;
        } else {
          totalBorrowed += d.remainingAmount;
          activeBorrowedCount++;
        }
      }
    }

    return DebtLedgerSummary(
      totalLent: totalLent,
      totalBorrowed: totalBorrowed,
      netBalance: totalLent - totalBorrowed,
      activeLentCount: activeLentCount,
      activeBorrowedCount: activeBorrowedCount,
      settledCount: settledCount,
    );
  });
});

/// Filtered list of debts based on active/settled tab and type filters.
final filteredDebtsProvider = Provider<AsyncValue<List<Debt>>>((ref) {
  final debtsAsync = ref.watch(allDebtsStreamProvider);
  final tabFilter = ref.watch(debtTabFilterProvider);
  final typeFilter = ref.watch(debtTypeFilterProvider);

  return debtsAsync.whenData((debts) {
    return debts.where((d) {
      // Tab filter (active vs settled)
      if (tabFilter == DebtTabFilter.active && d.isSettled) return false;
      if (tabFilter == DebtTabFilter.settled && !d.isSettled) return false;

      // Type filter
      final type = DebtType.fromId(d.type);
      if (typeFilter == DebtTypeFilter.lent && type != DebtType.lent) return false;
      if (typeFilter == DebtTypeFilter.borrowed && type != DebtType.borrowed) {
        return false;
      }

      return true;
    }).toList();
  });
});

/// Controller managing debt mutations.
class DebtController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Create a new debt record.
  Future<String?> createDebt({
    required String personName,
    required DebtType type,
    required double initialAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final userId = ref.read(activeUserIdProvider);
      final debtId = _uuid.v4();
      final now = DateTime.now();

      final companion = DebtsCompanion(
        id: drift.Value(debtId),
        userId: drift.Value(userId),
        personName: drift.Value(personName.trim()),
        type: drift.Value(type.id),
        initialAmount: drift.Value(initialAmount),
        remainingAmount: drift.Value(initialAmount),
        dueDate: drift.Value(dueDate),
        notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
        isSettled: const drift.Value(false),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      );

      await db.upsertDebt(companion);
      state = const AsyncValue.data(null);
      return debtId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Record a payment towards a debt.
  Future<bool> recordPayment({
    required String debtId,
    required double amount,
    DateTime? paidAt,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      final paymentId = _uuid.v4();
      final now = DateTime.now();

      final companion = DebtPaymentsCompanion(
        id: drift.Value(paymentId),
        debtId: drift.Value(debtId),
        amount: drift.Value(amount),
        paidAt: drift.Value(paidAt ?? now),
        notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
        createdAt: drift.Value(now),
      );

      await db.recordDebtPayment(
        payment: companion,
        paymentAmount: amount,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Toggle or set settled status directly.
  Future<void> toggleSettled({
    required String debtId,
    required bool isSettled,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      await db.updateDebtSettlementStatus(debtId, isSettled);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete a debt record and its child payment records.
  Future<void> deleteDebt(String debtId) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(appDatabaseProvider);
      await db.deleteDebt(debtId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final debtControllerProvider =
    NotifierProvider<DebtController, AsyncValue<void>>(
  DebtController.new,
);
