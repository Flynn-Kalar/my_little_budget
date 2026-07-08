import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import '../mobile_widgets.dart';

class MobileYearlyStatsScreen extends ConsumerWidget {
  const MobileYearlyStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(statsYearProvider);
    final trend = ref.watch(yearlyMonthlyTrendProvider);
    final categories = ref.watch(yearlyExpenseByCategoryProvider);

    return MobilePage(
      title: '연간 통계',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/stats'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('월간 통계'),
          ),
        ),
        MobileCard(
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(statsYearProvider.notifier).state = year - 1,
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 연도',
              ),
              Expanded(
                child: Text(
                  '$year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(statsYearProvider.notifier).state = year + 1,
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 연도',
              ),
            ],
          ),
        ),
        MobileAsync(
          value: trend,
          builder: (value) => _YearlySummary(rows: value),
        ),
        MobileAsync(
          value: categories,
          builder: (value) => _YearlyCategories(rows: value),
        ),
      ],
    );
  }
}

class _YearlySummary extends StatelessWidget {
  const _YearlySummary({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final income = rows.fold<int>(0, (sum, row) => sum + row.income);
    final expense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final net = income - expense;
    final incomeColor = context.appIncome;
    final expenseColor = context.appExpense;

    return MobileCard(
      child: Column(
        children: [
          AmountLine(
            label: '수입',
            value: formatKRW(income),
            valueColor: incomeColor,
          ),
          AmountLine(
            label: '지출',
            value: formatKRW(expense),
            valueColor: expenseColor,
          ),
          AmountLine(
            label: '순수입',
            value: formatKRW(net),
            valueColor: net < 0 ? expenseColor : incomeColor,
          ),
          const SizedBox(height: 8),
          const Divider(),
          SizedBox(height: 180, child: _MobileYearBars(rows: rows)),
          const SizedBox(height: 8),
          for (final row in rows)
            AmountLine(
              label: '${int.parse(row.month.substring(5, 7))}월',
              value: formatKRW(row.net),
              valueColor: row.net < 0 ? expenseColor : incomeColor,
            ),
        ],
      ),
    );
  }
}

class _MobileYearBars extends StatelessWidget {
  const _MobileYearBars({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold<int>(0, (max, row) {
      final rowMax = row.income > row.expense ? row.income : row.expense;
      return rowMax > max ? rowMax : max;
    });

    return BarChart(
      BarChartData(
        maxY: maxValue == 0 ? 1 : maxValue * 1.12,
        barTouchData: BarTouchData(enabled: true),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length || index.isOdd) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: rows[i].income.toDouble(),
                  color: context.appIncome,
                  width: 5,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: rows[i].expense.toDouble(),
                  color: context.appExpense,
                  width: 5,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _YearlyCategories extends StatelessWidget {
  const _YearlyCategories({required this.rows});

  final List<YearlyPivotRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('카테고리 통계가 없습니다.');
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final expense = context.appExpense;

    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리 요약', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  AmountLine(
                    label:
                        '${row.categoryName} · ${total == 0 ? 0 : (row.total / total * 100).round()}%',
                    value: formatKRW(row.total),
                    valueColor: expense,
                  ),
                  const SizedBox(height: 4),
                  _MobileCategoryBars(
                    values: row.months,
                    color: _parseColor(row.categoryColor, context.appAccent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileCategoryBars extends StatelessWidget {
  const _MobileCategoryBars({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (max, value) {
      return value > max ? value : max;
    });

    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: maxValue == 0 ? 0.08 : value / maxValue,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: value == 0
                            ? Theme.of(context).dividerColor
                            : color.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox(width: double.infinity),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _parseColor(String hex, Color fallback) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
