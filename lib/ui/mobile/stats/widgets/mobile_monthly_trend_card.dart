import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../mobile_widgets.dart';

class MobileMonthlyTrendCard extends StatefulWidget {
  const MobileMonthlyTrendCard({super.key, required this.rows});
  final List<MonthlyTrendRow> rows;

  @override
  State<MobileMonthlyTrendCard> createState() => _MobileMonthlyTrendCardState();
}

class _MobileMonthlyTrendCardState extends State<MobileMonthlyTrendCard> {
  String? _selectedMonth;
  List<MonthlyTrendRow> get rows => widget.rows;

  @override
  Widget build(BuildContext context) {
    final income = rows.fold<int>(0, (sum, row) => sum + row.income);
    final expense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final net = income - expense;
    final selected =
        rows.where((r) => r.periodKey == _selectedMonth).firstOrNull ??
        rows.lastOrNull;
    final colors = [context.appIncome, context.appExpense, context.appAccent];
    const labels = ['수입', '지출', '순액'];
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '최근 12개월 추세',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Column(
            key: const ValueKey('mobile-trend-totals'),
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    key: ValueKey('mobile-trend-total-$i'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors[i].withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: colors[i].withValues(alpha: .1),
                          child: Icon(
                            [Icons.south, Icons.north, Icons.bar_chart][i],
                            size: 20,
                            color: colors[i],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '12개월 ${labels[i]} 합계',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${i == 2 && net > 0 ? '+' : ''}${formatKRW([income, expense, net][i])}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: i == 2 && net < 0
                                      ? context.appExpense
                                      : colors[i],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('최근 12개월 거래 내역이 없습니다.', textAlign: TextAlign.center),
            )
          else ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        labels[i],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '단위: 만원 · 좌우로 밀어 월별 추세를 확인하세요.',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                key: const ValueKey('mobile-trend-chart-scroll'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  key: const ValueKey('mobile-trend-chart'),
                  width: math.max(
                    constraints.maxWidth,
                    rows.length * 48.0 + 64,
                  ),
                  height: 230,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, top: 10),
                    child: _TrendChart(
                      rows: rows,
                      onSelected: (index) => setState(
                        () => _selectedMonth = rows[index].periodKey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (selected != null)
              Container(
                key: const ValueKey('mobile-trend-selected-month'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appAccent.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${parseMonthKey(selected.month).year}년 ${parseMonthKey(selected.month).month}월',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Text(
                            '${labels[i]} ${formatKRW([selected.income, selected.expense, selected.net][i])}',
                            style: TextStyle(color: colors[i]),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('월별 상세', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '단위: 원 · 좌우로 밀어 전체 금액을 확인하세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SingleChildScrollView(
              key: const ValueKey('mobile-trend-table-scroll'),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('mobile-trend-monthly-table'),
                horizontalMargin: 8,
                columnSpacing: 20,
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 72,
                columns: [
                  const DataColumn(label: Text('월')),
                  for (var i = 0; i < 3; i++)
                    DataColumn(
                      numeric: true,
                      label: Text(
                        labels[i],
                        style: TextStyle(color: colors[i]),
                      ),
                    ),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${parseMonthKey(row.month).year}.${parseMonthKey(row.month).month.toString().padLeft(2, '0')}',
                          ),
                        ),
                        for (var i = 0; i < 3; i++)
                          DataCell(
                            Text(
                              '${i == 2 && row.net > 0 ? '+' : ''}${formatKRW([row.income, row.expense, row.net][i])}',
                              style: TextStyle(
                                color: i == 2 && row.net < 0
                                    ? context.appExpense
                                    : colors[i],
                                fontWeight: i == 2
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.rows, required this.onSelected});
  final List<MonthlyTrendRow> rows;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final minimum = rows.fold<int>(0, (n, r) => math.min(n, r.net));
    final maximum = rows.fold<int>(
      0,
      (n, r) => math.max(n, math.max(r.income, r.expense)),
    );
    final target = math.max(500000.0, (maximum - minimum) / 4);
    final scale = math
        .pow(10, (math.log(target) / math.ln10).floor())
        .toDouble();
    final step =
        [1.0, 2.0, 5.0, 10.0].firstWhere((n) => n * scale >= target) * scale;
    final colors = [context.appIncome, context.appExpense, context.appAccent];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, rows.length - 1).toDouble(),
        minY: (minimum / step).floor() * step,
        maxY: math.max(step, (maximum / step).ceil() * step),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            final spot = response?.lineBarSpots?.firstOrNull;
            if (event is FlTapUpEvent && spot != null) {
              onSelected(spot.x.toInt().clamp(0, rows.length - 1));
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF30364E),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 240,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                _tooltip(
                  rows[spot.x.toInt().clamp(0, rows.length - 1)],
                  spot,
                  colors,
                ),
            ],
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: step,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '${value.round() ~/ 10000}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
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
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 ||
                    index >= rows.length ||
                    value != index.toDouble()) {
                  return const SizedBox.shrink();
                }
                final date = parseMonthKey(rows[index].month);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${index == 0 || date.month == 1 ? '${date.year}년\n' : ''}${date.month}월',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          for (var series = 0; series < 3; series++)
            LineChartBarData(
              color: colors[series],
              barWidth: 2.5,
              isCurved: false,
              dotData: FlDotData(
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: colors[series],
                  strokeWidth: 1.5,
                  strokeColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: false,
                color: colors[series].withValues(alpha: .05),
              ),
              spots: [
                for (var i = 0; i < rows.length; i++)
                  FlSpot(
                    i.toDouble(),
                    [
                      rows[i].income,
                      rows[i].expense,
                      rows[i].net,
                    ][series].toDouble(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  LineTooltipItem _tooltip(
    MonthlyTrendRow row,
    LineBarSpot spot,
    List<Color> colors,
  ) {
    final date = parseMonthKey(row.month);
    final label = ['수입', '지출', '순액'][spot.barIndex];
    final amount = [row.income, row.expense, row.net][spot.barIndex];
    return LineTooltipItem(
      spot.barIndex == 0 ? '${date.year}년 ${date.month}월\n' : '',
      const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      children: [
        TextSpan(
          text: '● ',
          style: TextStyle(color: colors[spot.barIndex]),
        ),
        TextSpan(text: '$label  ${formatKRW(amount)}'),
      ],
    );
  }
}
