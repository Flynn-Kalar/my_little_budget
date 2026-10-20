import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/date.dart';
import '../desktop_section.dart';
import '../../shared/stats_detail_actions.dart';
import '../../shared/stats_period_tabs.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import 'widgets/monthly_insight_card.dart';
import 'widgets/stats_month_nav.dart';

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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '통계',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                ),
                StatsPeriodTabs(
                  yearly: false,
                  onChanged: (yearly) {
                    if (yearly) context.go('/stats/yearly');
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            StatsMonthNav(month: month),
            SizedBox(height: 16),
            MonthlyInsightCard(breakdown: breakdown, trend: trend),
            const SizedBox(height: 12),
            SizedBox(width: 360, child: StatsDetailActions(month: month)),
            SizedBox(height: 16),
            breakdown.when(
              data: (rows) {
                final effectiveCategory =
                    selectedCategory ?? (rows.isEmpty ? null : rows.first);
                return DesktopSection(
                  minWidth: 700,
                  child: _ExpenseBreakdownCard(
                    rows: rows,
                    tagRows: tagBreakdown,
                    netAmount: _netForMonth(trend, month),
                    selectedCategoryId: effectiveCategory?.categoryId,
                    selectedTag: selectedTag,
                  ),
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
                    child: DesktopSection(
                      minWidth: 700,
                      child: _CategoryAndTagDetailCard(
                        category: effectiveCategory,
                        categoryRows: selectedTransactions,
                        tagRows: tagTransactions,
                        tagBreakdown: tagBreakdown,
                        selectedTag: selectedTag,
                        month: month,
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            SizedBox(height: 16),
            trend.when(
              data: (rows) =>
                  DesktopSection(minWidth: 960, child: _TrendCard(rows: rows)),
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
            key: ValueKey('desktop-stats-category-${row.categoryId}'),
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
              key: ValueKey(
                'desktop-stats-tag-${row.isUntagged ? 'untagged' : row.tagId}',
              ),
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
            centerSpaceRadius: 68,
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
              style: TextStyle(color: context.desktopMuted, fontSize: 12),
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 116,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatKRW(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.desktopExpense,
                    fontSize: 14,
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
              style: TextStyle(color: context.desktopMuted, fontSize: 12),
            ),
            SizedBox(height: 2),
            SizedBox(
              width: 116,
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
                    fontSize: 14,
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
            centerSpaceRadius: 68,
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
              style: TextStyle(color: context.desktopMuted, fontSize: 12),
            ),
            SizedBox(height: 4),
            SizedBox(
              width: 116,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatKRW(total),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: context.desktopExpense,
                    fontSize: 14,
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
    super.key,
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
    super.key,
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
                  actions: StatsDetailActions(month: month, category: category),
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
                  actions: effectiveTag == null
                      ? null
                      : StatsDetailActions(
                          month: month,
                          category: category,
                          tag: effectiveTag,
                          showBudget: false,
                        ),
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
    this.actions,
  });

  final String title;
  final Color leadingColor;
  final AsyncValue<List<TransactionRow>> rows;
  final String emptyMessage;
  final Widget? actions;

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
          ?actions,
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
              const Expanded(
                child: Text(
                  '최근 12개월 추세',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '단위: 만원',
                style: TextStyle(color: context.desktopMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TrendLegend(label: '수입', color: context.desktopIncome),
                        const SizedBox(width: 14),
                        _TrendLegend(
                          label: '지출',
                          color: context.desktopExpense,
                        ),
                        const SizedBox(width: 14),
                        _TrendLegend(
                          label: '순액',
                          color: _trendNetColor(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      key: const ValueKey('desktop-trend-chart'),
                      height: 180,
                      child: rows.isEmpty
                          ? const _EmptyState(message: '최근 12개월 거래 내역이 없습니다.')
                          : _TrendChart(rows: rows),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                key: const ValueKey('desktop-trend-totals'),
                width: 200,
                child: Column(
                  children: [
                    _TrendSummaryTile(
                      label: '수입',
                      amount: totalIncome,
                      color: context.desktopIncome,
                      icon: Icons.south,
                    ),
                    const SizedBox(height: 8),
                    _TrendSummaryTile(
                      label: '지출',
                      amount: totalExpense,
                      color: context.desktopExpense,
                      icon: Icons.north,
                    ),
                    const SizedBox(height: 8),
                    _TrendSummaryTile(
                      label: '순액',
                      amount: totalNet,
                      color: totalNet < 0
                          ? context.desktopExpense
                          : _trendNetColor(context),
                      icon: Icons.bar_chart,
                      signed: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TrendTable(rows: rows),
          ],
        ],
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: context.desktopMuted, fontSize: 12)),
    ],
  );
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
            getTooltipColor: (_) => const Color(0xFF30364E),
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
              reservedSize: 38,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) {
                  return const SizedBox.shrink();
                }
                final date = parseMonthKey(rows[index].month);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${index == 0 || date.month == 1 ? '${date.year}년\n' : ''}${date.month}월',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.desktopMuted, fontSize: 10),
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
          _lineData(context, rows, (row) => row.net, _trendNetColor(context)),
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
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 2,
          strokeColor: context.desktopSurface,
        ),
      ),
      belowBarData: BarAreaData(show: false),
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
    _ => _trendNetColor(context),
  };
  return LineTooltipItem(
    spot.barIndex == 0
        ? '${parseMonthKey(row.month).year}년 ${parseMonthKey(row.month).month}월\n'
        : '',
    const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    children: [
      TextSpan(
        text: '● ',
        style: TextStyle(color: color),
      ),
      TextSpan(text: '$label  ${formatKRW(amount)}'),
    ],
  );
}

Color _trendNetColor(BuildContext context) {
  return context.desktopAccent;
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.signed = false,
  });
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final bool signed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: context.desktopMuted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Tooltip(
                message: formatKRW(amount),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${signed && amount > 0 ? '+' : ''}${formatKRW(amount)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.rows});
  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,##0.####', 'ko_KR');
    String amount(int value) => format.format(value / 10000);
    final style = DefaultTextStyle.of(context).style.copyWith(fontSize: 12);
    var columnWidth = 72.0;
    for (final row in rows) {
      var width = 72.0;
      final date = parseMonthKey(row.month);
      for (final value in [
        '${date.year}.${date.month.toString().padLeft(2, '0')}',
        amount(row.income),
        amount(row.expense),
        amount(row.net),
      ]) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        if (painter.width + 20 > width) width = painter.width + 20;
        painter.dispose();
      }
      if (width > columnWidth) columnWidth = width;
    }
    Widget cell(
      String text, {
      Color? color,
      bool bold = false,
      String? tooltip,
    }) {
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: style.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
      return tooltip == null
          ? content
          : Tooltip(message: tooltip, child: content);
    }

    TableRow values(
      String label,
      int Function(MonthlyTrendRow) read,
      Color color,
    ) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: _TrendLegend(label: label, color: color),
        ),
        for (final row in rows)
          cell(
            amount(read(row)),
            color: label == '순액' && read(row) < 0
                ? context.desktopExpense
                : null,
            tooltip: '${row.month} $label ${formatKRW(read(row))}',
          ),
      ],
    );
    return DesktopSection(
      minWidth: 64 + columnWidth * rows.length,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          key: const ValueKey('desktop-trend-monthly-table'),
          defaultColumnWidth: const FlexColumnWidth(),
          columnWidths: const {0: FixedColumnWidth(64)},
          border: TableBorder.all(
            color: context.desktopBorder.withValues(alpha: .65),
            width: .6,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: context.desktopSelectedSurface.withValues(alpha: .55),
              ),
              children: [
                cell('구분', color: context.desktopMuted, bold: true),
                for (final row in rows)
                  cell(
                    '${parseMonthKey(row.month).year}.${parseMonthKey(row.month).month.toString().padLeft(2, '0')}',
                    color: context.desktopMuted,
                    bold: true,
                  ),
              ],
            ),
            values('수입', (row) => row.income, context.desktopIncome),
            values('지출', (row) => row.expense, context.desktopExpense),
            values('순액', (row) => row.net, _trendNetColor(context)),
          ],
        ),
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
