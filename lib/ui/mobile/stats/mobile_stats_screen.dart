import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import '../mobile_widgets.dart';
import '../../shared/stats_detail_actions.dart';
import '../../shared/stats_period_tabs.dart';
import 'mobile_tag_breakdown_sheet.dart';
import 'widgets/mobile_monthly_trend_card.dart';

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
        StatsPeriodTabs(
          key: const ValueKey('mobile-stats-yearly-button'),
          yearly: false,
          onChanged: (yearly) {
            if (yearly) context.push('/stats/yearly');
          },
        ),
      ],
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(statsMonthProvider.notifier).state = value,
        ),
        _MobileMonthlyInsights(breakdown: breakdown, trend: trend),
        StatsDetailActions(month: month),
        const SizedBox(height: 12),
        MobileAsync(
          value: breakdown,
          builder: (value) => _Breakdown(
            rows: value,
            netAmount: _netForMonth(trend, month),
            month: month,
          ),
        ),
        MobileAsync(
          value: trend,
          builder: (value) => MobileMonthlyTrendCard(rows: value),
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
  const _Breakdown({
    required this.rows,
    required this.netAmount,
    required this.month,
  });

  final List<CategoryBreakdownRow> rows;
  final int? netAmount;
  final String month;

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
            child: _MobileDonut(
              rows: rows,
              total: total,
              netAmount: netAmount,
              onCategoryTap: (row) =>
                  showMobileTagBreakdown(context, month: month, category: row),
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            InkWell(
              key: ValueKey('mobile-stats-category-${row.categoryId}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  showMobileTagBreakdown(context, month: month, category: row),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AmountLine(
                            label:
                                '${row.categoryName} · ${total == 0 ? 0 : (row.total / total * 100).round()}%',
                            value: formatKRW(row.total),
                            valueColor: expense,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCategoryTotal == 0
                            ? 0
                            : row.total / maxCategoryTotal,
                        minHeight: 5,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _parseColor(row.categoryColor, context.appAccent),
                        ),
                      ),
                    ),
                  ],
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
    required this.onCategoryTap,
  });

  final List<CategoryBreakdownRow> rows;
  final int total;
  final int? netAmount;
  final ValueChanged<CategoryBreakdownRow> onCategoryTap;

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
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (event is! FlTapUpEvent) return;
                final index =
                    response?.touchedSection?.touchedSectionIndex ?? -1;
                if (index >= 0 && index < rows.length) {
                  onCategoryTap(rows[index]);
                }
              },
            ),
            sections: [
              for (final row in rows)
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

Color _parseColor(String hex, Color fallback) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
