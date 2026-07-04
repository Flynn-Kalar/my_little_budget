import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final breakdown = ref.watch(statsExpenseBreakdownProvider);
    final trend = ref.watch(statsMonthlyTrendProvider);
    final selectedCategory = ref.watch(statsSelectedCategoryProvider);
    final selectedTag = ref.watch(statsSelectedTagProvider);
    final detailPanelOpen = ref.watch(statsDetailPanelOpenProvider);
    final selectedTransactions = ref.watch(statsCategoryTransactionsProvider);
    final tagBreakdown = ref.watch(statsTagBreakdownProvider);
    final tagTransactions = ref.watch(statsTagTransactionsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '통계',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _StatsMonthNav(month: month),
            SizedBox(height: 16),
            _MonthlyInsightCard(breakdown: breakdown, trend: trend),
            SizedBox(height: 16),
            breakdown.when(
              data: (rows) {
                final effectiveCategory =
                    selectedCategory ?? (rows.isEmpty ? null : rows.first);
                return _ExpenseBreakdownCard(
                  rows: rows,
                  tagRows: tagBreakdown,
                  netAmount: _netForMonth(trend, month),
                  selectedCategoryId: effectiveCategory?.categoryId,
                  selectedTag: selectedTag,
                );
              },
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            if (detailPanelOpen)
              breakdown.maybeWhen(
                data: (rows) {
                  final effectiveCategory =
                      selectedCategory ?? (rows.isEmpty ? null : rows.first);
                  if (effectiveCategory == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _CategoryAndTagDetailCard(
                      category: effectiveCategory,
                      categoryRows: selectedTransactions,
                      tagRows: tagTransactions,
                      tagBreakdown: tagBreakdown,
                      selectedTag: selectedTag,
                      month: month,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            SizedBox(height: 16),
            trend.when(
              data: (rows) => _TrendCard(rows: rows),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            SizedBox(height: 16),
            const _YearlyTodoCard(),
            SizedBox(height: 40),
          ],
        ),
      ),
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

class _StatsMonthNav extends ConsumerWidget {
  const _StatsMonthNav({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      ref.read(statsMonthProvider.notifier).state = shiftMonth(month, delta);
      ref.read(statsSelectedCategoryProvider.notifier).state = null;
      ref.read(statsSelectedTagProvider.notifier).state = null;
      ref.read(statsDetailPanelOpenProvider.notifier).state = false;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(statsMonthProvider.notifier).state = currentMonthKey();
            ref.read(statsSelectedCategoryProvider.notifier).state = null;
            ref.read(statsSelectedTagProvider.notifier).state = null;
            ref.read(statsDetailPanelOpenProvider.notifier).state = false;
          },
          icon: Icon(Icons.calendar_month, size: 18),
          label: Text('${d.year}-${d.month.toString().padLeft(2, '0')}'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _MonthlyInsightCard extends StatelessWidget {
  const _MonthlyInsightCard({required this.breakdown, required this.trend});

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

          return _StatsCard(
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
                SizedBox(width: 12),
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
                SizedBox(width: 12),
                Expanded(
                  child: _InsightTile(
                    icon: Icons.query_stats_outlined,
                    label: '12개월 평균',
                    value: formatKRW(averageExpense),
                    color: context.desktopAccent,
                  ),
                ),
                SizedBox(width: 12),
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
            const _StatsCard(child: LinearProgressIndicator(minHeight: 3)),
        error: (error, _) => _ErrorCard(message: error.toString()),
      ),
      loading: () =>
          const _StatsCard(child: LinearProgressIndicator(minHeight: 3)),
      error: (error, _) => _ErrorCard(message: error.toString()),
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
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: context.desktopMuted)),
                  SizedBox(height: 4),
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

class _ExpenseBreakdownCard extends ConsumerWidget {
  const _ExpenseBreakdownCard({
    required this.rows,
    required this.tagRows,
    required this.netAmount,
    required this.selectedCategoryId,
    required this.selectedTag,
  });

  final List<CategoryBreakdownRow> rows;
  final AsyncValue<List<TagBreakdownRow>> tagRows;
  final int? netAmount;
  final int? selectedCategoryId;
  final TagBreakdownRow? selectedTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final maxCategoryTotal = rows.fold<int>(
      0,
      (max, row) => row.total > max ? row.total : max,
    );

    return _StatsCard(
      child: rows.isEmpty
          ? const _EmptyState(message: '선택한 월에 지출 내역이 없습니다.')
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CategoryBreakdownPane(
                    rows: rows,
                    total: total,
                    maxCategoryTotal: maxCategoryTotal,
                    netAmount: netAmount,
                    selectedCategoryId: selectedCategoryId,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: tagRows.when(
                    data: (rows) =>
                        _TagBreakdownPane(rows: rows, selectedTag: selectedTag),
                    loading: () => const LinearProgressIndicator(minHeight: 3),
                    error: (error, _) =>
                        _ErrorInline(message: error.toString()),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryBreakdownPane extends ConsumerWidget {
  const _CategoryBreakdownPane({
    required this.rows,
    required this.total,
    required this.maxCategoryTotal,
    required this.netAmount,
    required this.selectedCategoryId,
  });

  final List<CategoryBreakdownRow> rows;
  final int total;
  final int maxCategoryTotal;
  final int? netAmount;
  final int? selectedCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '카테고리별',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: _CategoryDonutChart(
            rows: rows,
            total: total,
            netAmount: netAmount,
          ),
        ),
        SizedBox(height: 10),
        for (final row in rows)
          _BreakdownRow(
            row: row,
            total: total,
            maxTotal: maxCategoryTotal,
            selected: selectedCategoryId == row.categoryId,
            onTap: () {
              final current = ref.read(statsSelectedCategoryProvider);
              ref.read(statsSelectedCategoryProvider.notifier).state =
                  current?.categoryId == row.categoryId ? null : row;
              ref.read(statsSelectedTagProvider.notifier).state = null;
              ref.read(statsDetailPanelOpenProvider.notifier).state = true;
            },
          ),
      ],
    );
  }
}

class _TagBreakdownPane extends ConsumerWidget {
  const _TagBreakdownPane({required this.rows, required this.selectedTag});

  final List<TagBreakdownRow> rows;
  final TagBreakdownRow? selectedTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final maxTotal = rows.fold<int>(
      0,
      (max, row) => row.total > max ? row.total : max,
    );
    final effectiveTag = _effectiveSelectedTag(rows, selectedTag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '태그별',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyState(message: '선택한 카테고리에 태그가 붙은 지출 내역이 없습니다.')
        else ...[
          SizedBox(
            height: 220,
            child: _TagDonutChart(rows: rows, total: total),
          ),
          SizedBox(height: 10),
          for (final row in rows)
            _TagBreakdownRow(
              row: row,
              total: total,
              maxTotal: maxTotal,
              selected: _sameTag(row, effectiveTag),
              onTap: () {
                ref.read(statsSelectedTagProvider.notifier).state = row;
                ref.read(statsDetailPanelOpenProvider.notifier).state = true;
              },
            ),
        ],
      ],
    );
  }
}

class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({
    required this.rows,
    required this.total,
    required this.netAmount,
  });

  final List<CategoryBreakdownRow> rows;
  final int total;
  final int? netAmount;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
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
                  color: _parseColor(row.categoryColor, context.desktopMuted),
                  radius: 28,
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
              style: TextStyle(color: context.desktopMuted, fontSize: 10),
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 96,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatKRW(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.desktopExpense,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 5),
            Text(
              '순액',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.desktopMuted, fontSize: 10),
            ),
            SizedBox(height: 2),
            SizedBox(
              width: 96,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  netAmount == null ? '-' : formatKRW(netAmount!),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: netAmount == null || netAmount! >= 0
                        ? context.desktopIncome
                        : context.desktopExpense,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TagDonutChart extends StatelessWidget {
  const _TagDonutChart({required this.rows, required this.total});

  final List<TagBreakdownRow> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
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
                  color: _parseColor(row.tagColor, context.desktopMuted),
                  radius: 28,
                  showTitle: false,
                ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '태그 합계',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.desktopMuted, fontSize: 10),
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 96,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatKRW(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.desktopExpense,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.row,
    required this.total,
    required this.maxTotal,
    required this.selected,
    required this.onTap,
  });

  final CategoryBreakdownRow row;
  final int total;
  final int maxTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (row.total * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? context.desktopSelectedSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                _ColorDot(
                  color: _parseColor(row.categoryColor, context.desktopMuted),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.categoryName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 10),
                _PercentPill(
                  percent: percent,
                  weight: maxTotal == 0 ? 0 : row.total / maxTotal,
                  color: _parseColor(row.categoryColor, context.desktopMuted),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Text(
                    formatKRW(row.total),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagBreakdownRow extends StatelessWidget {
  const _TagBreakdownRow({
    required this.row,
    required this.total,
    required this.maxTotal,
    required this.selected,
    required this.onTap,
  });

  final TagBreakdownRow row;
  final int total;
  final int maxTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (row.total * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? context.desktopSelectedSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                _ColorDot(
                  color: _parseColor(row.tagColor, context.desktopMuted),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.isUntagged ? row.tagName : '#${row.tagName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 10),
                _PercentPill(
                  percent: percent,
                  weight: maxTotal == 0 ? 0 : row.total / maxTotal,
                  color: _parseColor(row.tagColor, context.desktopMuted),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Text(
                    formatKRW(row.total),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({
    required this.percent,
    required this.weight,
    required this.color,
  });

  final int percent;
  final double weight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = weight.clamp(0.0, 1.0);
    return SizedBox(
      width: 64,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: context.desktopSelectedSurface,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Center(
            child: Text(
              '$percent%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

TagBreakdownRow? _effectiveSelectedTag(
  List<TagBreakdownRow> rows,
  TagBreakdownRow? selected,
) {
  if (rows.isEmpty) return null;
  if (selected == null) return rows.first;
  for (final row in rows) {
    if (_sameTag(row, selected)) return row;
  }
  return rows.first;
}

bool _sameTag(TagBreakdownRow? a, TagBreakdownRow? b) {
  if (a == null || b == null) return false;
  return a.isUntagged == b.isUntagged && a.tagId == b.tagId;
}

class _CategoryAndTagDetailCard extends ConsumerWidget {
  const _CategoryAndTagDetailCard({
    required this.category,
    required this.categoryRows,
    required this.tagRows,
    required this.tagBreakdown,
    required this.selectedTag,
    required this.month,
  });

  final CategoryBreakdownRow category;
  final AsyncValue<List<TransactionRow>> categoryRows;
  final AsyncValue<List<TransactionRow>> tagRows;
  final AsyncValue<List<TagBreakdownRow>> tagBreakdown;
  final TagBreakdownRow? selectedTag;
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);
    final effectiveTag = tagBreakdown.maybeWhen(
      data: (rows) => _effectiveSelectedTag(rows, selectedTag),
      orElse: () => null,
    );

    return _StatsCard(
      child: Column(
        children: [
          Row(
            children: [
              Spacer(),
              IconButton(
                tooltip: '상세 닫기',
                onPressed: () =>
                    ref.read(statsDetailPanelOpenProvider.notifier).state =
                        false,
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailPane(
                  title:
                      '${d.year}-${d.month.toString().padLeft(2, '0')} ${category.categoryName} 상세',
                  leadingColor: _parseColor(
                    category.categoryColor,
                    context.desktopMuted,
                  ),
                  rows: categoryRows,
                  emptyMessage: '선택한 카테고리의 지출 내역이 없습니다.',
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: _DetailPane(
                  title: effectiveTag == null
                      ? '${category.categoryName} 태그 상세'
                      : '${effectiveTag.isUntagged ? effectiveTag.tagName : '#${effectiveTag.tagName}'} 상세',
                  leadingColor: _parseColor(
                    effectiveTag?.tagColor ?? '#94a3b8',
                    context.desktopMuted,
                  ),
                  rows: tagRows,
                  emptyMessage: '선택한 태그의 지출 내역이 없습니다.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.title,
    required this.leadingColor,
    required this.rows,
    required this.emptyMessage,
  });

  final String title;
  final Color leadingColor;
  final AsyncValue<List<TransactionRow>> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return rows.when(
      data: (rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ColorDot(color: leadingColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (rows.isEmpty)
            _EmptyState(message: emptyMessage)
          else
            Column(
              children: [
                const _CategoryDetailHeader(),
                const Divider(height: 1),
                for (final row in rows) _CategoryDetailRow(row: row),
              ],
            ),
        ],
      ),
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (error, _) => _ErrorInline(message: error.toString()),
    );
  }
}

class _CategoryDetailHeader extends StatelessWidget {
  const _CategoryDetailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('날짜')),
          Expanded(flex: 4, child: Text('거래명/메모')),
          Expanded(flex: 3, child: Text('계좌')),
          Expanded(flex: 3, child: Text('태그')),
          Expanded(flex: 3, child: Text('금액', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _CategoryDetailRow extends StatelessWidget {
  const _CategoryDetailRow({required this.row});

  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final title = row.memo?.trim().isNotEmpty == true
        ? row.memo!.trim()
        : row.categoryName ?? '거래';
    final tags = row.tags.map((tag) => '#${tag.name}').join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(row.occurredOn)),
          Expanded(
            flex: 4,
            child: Text(title, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.accountName ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tags.isEmpty ? '-' : tags,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(row.amount),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.desktopExpense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final totalIncome = rows.fold<int>(0, (sum, row) => sum + row.income);
    final totalExpense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final totalNet = totalIncome - totalExpense;

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '최근 12개월 추세',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '축: 만원',
                style: TextStyle(color: context.desktopMuted, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TrendSummaryTile(
                  label: '수입',
                  amount: totalIncome,
                  color: context.desktopIncome,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TrendSummaryTile(
                  label: '지출',
                  amount: totalExpense,
                  color: context.desktopExpense,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _TrendSummaryTile(
                  label: '순액',
                  amount: totalNet,
                  color: totalNet < 0
                      ? context.desktopExpense
                      : context.desktopAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (rows.isEmpty)
            const _EmptyState(message: '최근 12개월 거래 내역이 없습니다.')
          else ...[
            SizedBox(height: 210, child: _TrendChart(rows: rows)),
            SizedBox(height: 12),
            _TrendTable(rows: rows),
          ],
        ],
      ),
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

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.rows});

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
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return [
                for (final spot in spots)
                  _trendTooltipItem(context, rows, spot),
              ];
            },
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _axisStep.toDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: context.desktopBorder, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: _axisStep.toDouble(),
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _axisLabel(value),
                    style: TextStyle(color: context.desktopMuted, fontSize: 10),
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
                    '${parseMonthKey(rows[index].month).month}',
                    style: TextStyle(color: context.desktopMuted, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          _lineData(context, rows, (row) => row.income, context.desktopIncome),
          _lineData(
            context,
            rows,
            (row) => row.expense,
            context.desktopExpense,
          ),
          _lineData(context, rows, (row) => row.net, context.desktopAccent),
        ],
      ),
    );
  }

  LineChartBarData _lineData(
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
          strokeColor: context.desktopSurface,
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

LineTooltipItem _trendTooltipItem(
  BuildContext context,
  List<MonthlyTrendRow> rows,
  LineBarSpot spot,
) {
  final index = spot.x.toInt();
  final safeIndex = index.clamp(0, rows.length - 1);
  final row = rows[safeIndex];
  final label = switch (spot.barIndex) {
    0 => '수입',
    1 => '지출',
    _ => '순액',
  };
  final amount = switch (spot.barIndex) {
    0 => row.income,
    1 => row.expense,
    _ => row.net,
  };
  final color = switch (spot.barIndex) {
    0 => context.desktopIncome,
    1 => context.desktopExpense,
    _ => context.desktopAccent,
  };
  return LineTooltipItem(
    '$label ${formatKRW(amount)}',
    TextStyle(color: color, fontWeight: FontWeight.w800),
  );
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({
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

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final row in rows) _TrendMonthChip(row: row)],
    );
  }
}

class _TrendMonthChip extends StatelessWidget {
  const _TrendMonthChip({required this.row});

  final MonthlyTrendRow row;

  @override
  Widget build(BuildContext context) {
    final d = parseMonthKey(row.month);
    final netColor = row.net < 0
        ? context.desktopExpense
        : Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: 164,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.desktopSelectedSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.year}.${d.month}',
                style: TextStyle(
                  color: context.desktopMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              _MiniAmount(
                label: '수입',
                amount: row.income,
                color: context.desktopIncome,
              ),
              _MiniAmount(
                label: '지출',
                amount: row.expense,
                color: context.desktopExpense,
              ),
              _MiniAmount(label: '순액', amount: row.net, color: netColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(color: context.desktopMuted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            formatKRW(amount),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _YearlyTodoCard extends StatelessWidget {
  const _YearlyTodoCard();

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, color: context.desktopMuted),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연간 통계', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text(
                  '연도별 월간 수입/지출과 카테고리별 지출 흐름을 확인합니다.',
                  style: TextStyle(color: context.desktopMuted),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/stats/yearly'),
            icon: Icon(Icons.open_in_new, size: 18),
            label: Text('연간 통계 열기'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

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

class _ErrorInline extends StatelessWidget {
  const _ErrorInline({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
