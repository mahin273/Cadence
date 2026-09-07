import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_models.dart';
import '../providers/finance_provider.dart';

/// Interactive donut chart powered by fl_chart displaying category breakdown with tap highlights.
class CategoryDonutChart extends ConsumerStatefulWidget {
  const CategoryDonutChart({super.key});

  @override
  ConsumerState<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends ConsumerState<CategoryDonutChart> {
  int _touchedIndex = -1;

  static const Map<String, Color> _categoryColors = {
    'food': Colors.orange,
    'transport': Colors.blue,
    'housing': Colors.indigo,
    'utilities': Colors.teal,
    'entertainment': Colors.purple,
    'health': Colors.green,
    'shopping': Colors.pink,
    'other': Colors.blueGrey,
  };

  Color _getColorForCategory(String category) {
    return _categoryColors[category.toLowerCase()] ?? Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categorySpends = ref.watch(categorySpendStreamProvider).value ?? [];
    final totalSpend = ref.watch(totalMonthlySpendStreamProvider).value ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spending by Category',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${totalSpend.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (totalSpend <= 0 || categorySpends.isEmpty)
              _buildEmptyState(context)
            else ...[
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 60,
                        sections: _buildSections(categorySpends, totalSpend),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${totalSpend.toStringAsFixed(0)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildLegend(categorySpends, totalSpend, theme),
            ],
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(
    List<CategorySpend> categorySpends,
    double totalSpend,
  ) {
    return List.generate(categorySpends.length, (i) {
      final item = categorySpends[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 50.0 : 40.0;
      final color = _getColorForCategory(item.category);
      final percentage =
          totalSpend > 0 ? (item.totalAmount / totalSpend * 100) : 0.0;

      return PieChartSectionData(
        color: color,
        value: item.totalAmount,
        title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.pie_chart_outline_rounded,
                size: 40,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No expenses this month',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add expenses to see your category breakdown chart.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(
    List<CategorySpend> categorySpends,
    double totalSpend,
    ThemeData theme,
  ) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: categorySpends.map((item) {
        final color = _getColorForCategory(item.category);
        final percentage =
            totalSpend > 0 ? (item.totalAmount / totalSpend * 100) : 0.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item.category}: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '\$${item.totalAmount.toStringAsFixed(0)} (${percentage.toStringAsFixed(0)}%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
