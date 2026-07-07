import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../shared/stats_providers.dart';
import '../mobile_widgets.dart';

class MobileStatsScreen extends ConsumerWidget {
  const MobileStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final breakdown = ref.watch(statsExpenseBreakdownProvider);
    final trend = ref.watch(statsMonthlyTrendProvider);

    return MobilePage(
      title: '통계',
      actions: [
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-stats-yearly-button'),
          onPressed: () {
            context.push('/stats/yearly');
          },
          icon: const Icon(Icons.calendar_view_month_outlined, size: 18),
          label: const Text('연간'),
        ),
      ],
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(statsMonthProvider.notifier).state = value,
        ),
        _MobileMonthlyInsights(breakdown: breakdown, trend: trend),
        MobileAsync(
          value: breakdown,
          builder: (value) =>
              _Breakdown(rows: value, netAmount: _netForMonth(trend, month)),
        ),
        MobileAsync(
          value: trend,
          builder: (value) => _Trend(rows: value),
        ),
      ],
    );
  }
}

int? _netForMonth(AsyncValue<List<MonthlyTrendRow>> trend, String month) {
  return trend.maybeWhen(
    data: (rows) {
      for (final row in rows) {
        if (row.month == month) return row.net;
      }
      return rows.isEmpty ? null : rows.last.net;
    },
    orElse: () => null,
  );
}

class _MobileMonthlyInsights extends StatelessWidget {
  const _MobileMonthlyInsights({required this.breakdown, required this.trend});

  final AsyncValue<List<CategoryBreakdownRow>> breakdown;
  final AsyncValue<List<MonthlyTrendRow>> trend;

  @override
  Widget build(BuildContext context) {
    return breakdown.when(
      data: (categories) => trend.when(
        data: (trendRows) {
          final expense = categories.fold<int>(
            0,
            (sum, row) => sum + row.total,
          );
          final previous = trendRows.length >= 2
              ? trendRows[trendRows.length - 2].expense
              : 0;
          final diff = expense - previous;
          final top = categories.isEmpty ? null : categories.first;

          return MobileCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InsightPill(
                        label: '이번 달 지출',
                        value: formatKRW(expense),
                        color: context.appExpense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InsightPill(
                        label: '전월 대비',
                        value: previous == 0
                            ? '-'
                            : '${diff >= 0 ? '+' : ''}${formatKRW(diff)}',
                        color: diff > 0
                            ? context.appExpense
                            : context.appIncome,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InsightPill(
                        label: '12개월 평균',
                        value: trendRows.isEmpty
                            ? formatKRW(0)
                            : formatKRW(
                                (trendRows.fold<int>(
                                          0,
                                          (sum, row) => sum + row.expense,
                                        ) /
                                        trendRows.length)
                                    .round(),
                              ),
                        color: context.appAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InsightPill(
                        label: '최대 카테고리',
                        value: top?.categoryName ?? '-',
                        color: top == null
                            ? Theme.of(context).colorScheme.onSurface
                            : _parseColor(top.categoryColor, context.appAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () =>
            const MobileCard(child: LinearProgressIndicator(minHeight: 3)),
        error: (error, _) => MobileCard(
          child: Text(
            error.toString(),
            style: TextStyle(color: context.appExpense),
          ),
        ),
      ),
      loading: () =>
          const MobileCard(child: LinearProgressIndicator(minHeight: 3)),
      error: (error, _) => MobileCard(
        child: Text(
          error.toString(),
          style: TextStyle(color: context.appExpense),
        ),
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows, required this.netAmount});

  final List<CategoryBreakdownRow> rows;
  final int? netAmount;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('지출 통계가 없습니다.');
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final maxCategoryTotal = rows.fold<int>(
      0,
      (max, row) => row.total > max ? row.total : max,
    );
    final expense = context.appExpense;
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리별 지출', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: _MobileDonut(rows: rows, total: total, netAmount: netAmount),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            AmountLine(
              label:
                  '${row.categoryName} · ${total == 0 ? 0 : (row.total / total * 100).round()}%',
              value: formatKRW(row.total),
              valueColor: expense,
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxCategoryTotal == 0 ? 0 : row.total / maxCategoryTotal,
                minHeight: 5,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _parseColor(row.categoryColor, context.appAccent),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MobileDonut extends StatelessWidget {
  const _MobileDonut({
    required this.rows,
    required this.total,
    required this.netAmount,
  });

  final List<CategoryBreakdownRow> rows;
  final int total;
  final int? netAmount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 58,
            sectionsSpace: 2,
            startDegreeOffset: -90,
            sections: [
              for (final row in rows.take(8))
                PieChartSectionData(
                  value: row.total.toDouble(),
                  color: _parseColor(row.categoryColor, context.appAccent),
                  radius: 26,
                  showTitle: false,
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '총 지출',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatKRW(total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appExpense,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '순액',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              netAmount == null ? '-' : formatKRW(netAmount!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: netAmount == null || netAmount! >= 0
                    ? context.appIncome
                    : context.appExpense,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('월별 추세가 없습니다.');
    final income = context.appIncome;
    final expense = context.appExpense;
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '월별 추세',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '(단위: 만원)',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _TrendLegendItem(label: '수입', color: context.appIncome),
              _TrendLegendItem(label: '지출', color: context.appExpense),
              _TrendLegendItem(label: '순액', color: context.appAccent),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(height: 170, child: _MobileTrendChart(rows: rows)),
          const SizedBox(height: 8),
          for (final row in rows.take(6))
            _MonthlyTrendLine(row: row, income: income, expense: expense),
        ],
      ),
    );
  }
}

class _TrendLegendItem extends StatelessWidget {
  const _TrendLegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.76),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrendLine extends StatelessWidget {
  const _MonthlyTrendLine({
    required this.row,
    required this.income,
    required this.expense,
  });

  final MonthlyTrendRow row;
  final Color income;
  final Color expense;

  @override
  Widget build(BuildContext context) {
    final month = parseMonthKey(row.month).month;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$month월',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              '수입 ${formatKRW(row.income)} · 지출 ${formatKRW(row.expense)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatKRW(row.net),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: row.net < 0 ? expense : income,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTrendChart extends StatelessWidget {
  const _MobileTrendChart({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final minY = _axisMin(rows);
    final maxY = _axisMax(rows);

    return LineChart(
      LineChartData(
        minY: minY.toDouble(),
        maxY: maxY.toDouble(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: const LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 96,
            tooltipPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _axisStep.toDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _axisStep.toDouble(),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _axisLabel(value),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
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
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length || index.isOdd) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${parseMonthKey(rows[index].month).month}',
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
        lineBarsData: [
          _line(context, rows, (row) => row.income, context.appIncome),
          _line(context, rows, (row) => row.expense, context.appExpense),
          _line(context, rows, (row) => row.net, context.appAccent),
        ],
      ),
    );
  }

  LineChartBarData _line(
    BuildContext context,
    List<MonthlyTrendRow> rows,
    int Function(MonthlyTrendRow row) read,
    Color color,
  ) {
    return LineChartBarData(
      isCurved: false,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 2,
          strokeColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
      spots: [
        for (var i = 0; i < rows.length; i++)
          FlSpot(i.toDouble(), read(rows[i]).toDouble()),
      ],
    );
  }
}

const int _axisStep = 500000;

int _axisMax(List<MonthlyTrendRow> rows) {
  final maxValue = rows.fold<int>(0, (max, row) {
    final rowMax = [
      row.income,
      row.expense,
      row.net > 0 ? row.net : 0,
    ].reduce((a, b) => a > b ? a : b);
    return rowMax > max ? rowMax : max;
  });
  if (maxValue <= 0) return _axisStep;
  return ((maxValue + _axisStep - 1) ~/ _axisStep) * _axisStep;
}

int _axisMin(List<MonthlyTrendRow> rows) {
  final minNet = rows.fold<int>(0, (min, row) => row.net < min ? row.net : min);
  if (minNet >= 0) return 0;
  return ((minNet - _axisStep + 1) ~/ _axisStep) * _axisStep;
}

String _axisLabel(double value) => '${value.round() ~/ 10000}';

Color _parseColor(String hex, Color fallback) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
