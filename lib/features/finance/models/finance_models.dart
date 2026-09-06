import '../../../core/database/app_database.dart';

/// Aggregated spend totals for a category over a time period.
class CategorySpend {
  final String category;
  final double totalAmount;

  const CategorySpend({
    required this.category,
    required this.totalAmount,
  });

  @override
  String toString() => 'CategorySpend($category: \$${totalAmount.toStringAsFixed(2)})';
}

/// Computed status comparing a budget limit against actual monthly spend.
class BudgetProgress {
  final Budget budget;
  final double spent;
  final double remaining;
  final double percentage;
  final bool isOverBudget;

  const BudgetProgress({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.isOverBudget,
  });

  @override
  String toString() =>
      'BudgetProgress(${budget.category}: spent \$${spent.toStringAsFixed(2)} of \$${budget.monthlyLimit.toStringAsFixed(2)} - ${(percentage * 100).toStringAsFixed(1)}%)';
}
