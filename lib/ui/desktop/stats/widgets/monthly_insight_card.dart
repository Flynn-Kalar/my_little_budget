import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';

class MonthlyInsightCard extends StatelessWidget {
  const MonthlyInsightCard({
    super.key,
    required this.breakdown,
    required this.trend,
  });

  final AsyncValue<List<CategoryBreakdownRow>> breakdown;
  final AsyncValue<List<MonthlyTrendRow>> trend;

  @override
  Widget build(BuildContext context) {
    return breakdown.when(
      data: (categoryRows) => trend.when(
        data: (trendRows) {
          final monthExpense = categoryRows.fold<int>(
            0,
            (sum, row) => sum + row.total,
          );
          final previousExpense = trendRows.length >= 2
              ? trendRows[trendRows.length - 2].expense
              : 0;
          final diff = monthExpense - previousExpense;
          final averageExpense = trendRows.isEmpty
              ? 0
              : (trendRows.fold<int>(0, (sum, row) => sum + row.expense) /
                        trendRows.length)
                    .round();
          final topCategory = categoryRows.isEmpty ? null : categoryRows.first;

          return _InsightCard(
            child: Row(
              children: [
                Expanded(
                  child: _InsightTile(
                    icon: Icons.payments_outlined,
                    label: '이번 달 지출',
                    value: formatKRW(monthExpense),
                    color: context.desktopExpense,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InsightTile(
                    icon: diff <= 0
                        ? Icons.trending_down_outlined
                        : Icons.trending_up_outlined,
                    label: '전월 대비',
                    value: previousExpense == 0
                        ? '-'
                        : '${diff >= 0 ? '+' : ''}${formatKRW(diff)}',
                    color: diff > 0
                        ? context.desktopExpense
                        : context.desktopIncome,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InsightTile(
                    icon: Icons.query_stats_outlined,
                    label: '12개월 평균',
                    value: formatKRW(averageExpense),
                    color: context.desktopAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InsightTile(
                    icon: Icons.category_outlined,
                    label: '최다 지출 카테고리',
                    value: topCategory == null
                        ? '-'
                        : '${topCategory.categoryName} · ${formatKRW(topCategory.total)}',
                    color: topCategory == null
                        ? context.desktopMuted
                        : _parseColor(
                            topCategory.categoryColor,
                            context.desktopAccent,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const _InsightCard(child: LinearProgressIndicator(minHeight: 3)),
        error: (error, _) => _InsightError(message: error.toString()),
      ),
      loading: () =>
          const _InsightCard(child: LinearProgressIndicator(minHeight: 3)),
      error: (error, _) => _InsightError(message: error.toString()),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: context.desktopMuted)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightError extends StatelessWidget {
  const _InsightError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      child: Text(message, style: TextStyle(color: context.desktopExpense)),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.child});

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
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
