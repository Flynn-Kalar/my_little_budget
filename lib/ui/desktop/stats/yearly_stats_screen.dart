import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'package:my_little_budget/features/stats/providers.dart';

class YearlyStatsScreen extends ConsumerWidget {
  const YearlyStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(statsYearProvider);
    final years = ref.watch(availableStatsYearsProvider);
    final trend = ref.watch(yearlyMonthlyTrendProvider);
    final categories = ref.watch(yearlyExpenseByCategoryProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/stats'),
              icon: Icon(Icons.chevron_left),
              label: Text('월간 통계'),
            ),
            SizedBox(height: 8),
            Text(
              '연간 통계',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            years.when(
              data: (items) => _YearSelector(year: year, years: items),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            SizedBox(height: 16),
            trend.when(
              data: (rows) => _YearlyMonthlyCard(year: year, rows: rows),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            SizedBox(height: 16),
            categories.when(
              data: (rows) => _YearlyCategoryCard(rows: rows),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _YearSelector extends ConsumerWidget {
  const _YearSelector({required this.year, required this.years});

  final int year;
  final List<int> years;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowYear = DateTime.now().year;
    final options = {...years, year, nowYear}.toList()
      ..sort((a, b) => b.compareTo(a));

    return _StatsCard(
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: context.desktopMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text('조회 연도', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          DropdownButton<int>(
            key: const ValueKey('yearly-stats-year-dropdown'),
            value: year,
            items: [
              for (final item in options)
                DropdownMenuItem(value: item, child: Text('$item년')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(statsYearProvider.notifier).state = value;
              }
            },
          ),
        ],
      ),
    );
  }
}

class _YearlyMonthlyCard extends StatelessWidget {
  const _YearlyMonthlyCard({required this.year, required this.rows});

  final int year;
  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final hasData = rows.any((row) => row.income != 0 || row.expense != 0);
    final totalIncome = rows.fold<int>(0, (sum, row) => sum + row.income);
    final totalExpense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final totalNet = totalIncome - totalExpense;

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$year년 월별 수입/지출',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: '연간 수입',
                  amount: totalIncome,
                  color: context.desktopIncome,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: '연간 지출',
                  amount: totalExpense,
                  color: context.desktopExpense,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: '연간 순액',
                  amount: totalNet,
                  color: totalNet < 0
                      ? context.desktopExpense
                      : context.desktopAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (!hasData)
            const _EmptyState(
              key: ValueKey('yearly-monthly-empty'),
              message: '선택한 연도에 거래 내역이 없습니다.',
            )
          else ...[
            SizedBox(height: 240, child: _YearlyMonthlyChart(rows: rows)),
            SizedBox(height: 16),
            _MonthlyTable(
              key: const ValueKey('yearly-monthly-table'),
              rows: rows,
            ),
          ],
        ],
      ),
    );
  }
}

class _YearlyMonthlyChart extends StatelessWidget {
  const _YearlyMonthlyChart({required this.rows});

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
              FlLine(color: context.desktopBorder, strokeWidth: 1),
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
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${index + 1}월',
                    style: TextStyle(color: context.desktopMuted, fontSize: 11),
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
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: rows[i].income.toDouble(),
                  color: context.desktopIncome,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: rows[i].expense.toDouble(),
                  color: context.desktopExpense,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({super.key, required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MonthlyHeader(),
        const Divider(height: 1),
        for (final row in rows) _MonthlyRow(row: row),
      ],
    );
  }
}

class _MonthlyHeader extends StatelessWidget {
  const _MonthlyHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('월')),
          Expanded(flex: 3, child: Text('수입', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('지출', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('순액', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({required this.row});

  final MonthlyTrendRow row;

  @override
  Widget build(BuildContext context) {
    final d = parseMonthKey(row.month);
    final netColor = row.net < 0
        ? context.desktopExpense
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('${d.month}월')),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.income), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.expense), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(row.net),
              textAlign: TextAlign.right,
              style: TextStyle(color: netColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyCategoryCard extends StatelessWidget {
  const _YearlyCategoryCard({required this.rows});

  final List<YearlyPivotRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '카테고리별 연간 지출',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                formatKRW(total),
                style: TextStyle(
                  color: context.desktopExpense,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (rows.isEmpty)
            const _EmptyState(
              key: ValueKey('yearly-category-empty'),
              message: '선택한 연도에 지출 내역이 없습니다.',
            )
          else
            Column(
              key: const ValueKey('yearly-category-list'),
              children: [
                for (final row in rows) _CategoryRow(row: row, total: total),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.row, required this.total});

  final YearlyPivotRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (row.total * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _ColorDot(
            color: _parseColor(row.categoryColor, context.desktopMuted),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              row.categoryName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: _CategoryMonthBars(
              values: row.months,
              color: _parseColor(row.categoryColor, context.desktopMuted),
            ),
          ),
          SizedBox(width: 12),
          Text('$percent%', style: TextStyle(color: context.desktopMuted)),
          SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: Text(
              formatKRW(row.total),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMonthBars extends StatelessWidget {
  const _CategoryMonthBars({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(0, (max, value) {
      return value > max ? value : max;
    });

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: maxValue == 0 ? 0.08 : value / maxValue,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: value == 0
                            ? context.desktopBorder
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.desktopBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.desktopMuted)),
            SizedBox(height: 4),
            Text(
              formatKRW(amount),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: TextStyle(color: context.desktopMuted)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Text(message, style: TextStyle(color: context.desktopExpense)),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox(width: 10, height: 10),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

Color _parseColor(String hex, Color fallback) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
