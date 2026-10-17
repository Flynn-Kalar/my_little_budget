import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/providers.dart';
import '../../shared/stats_detail_actions.dart';
import 'mobile_tag_transactions_sheet.dart';

// Keep the sheet's query tied to the tapped month and category, independently
// of desktop selection state.
final mobileStatsTagBreakdownProvider = FutureProvider.autoDispose
    .family<List<TagBreakdownRow>, ({String month, int categoryId})>((
      ref,
      key,
    ) {
      return ref
          .watch(transactionsDaoProvider)
          .expenseByTag(key.month, key.categoryId);
    });

Future<void> showMobileTagBreakdown(
  BuildContext context, {
  required String month,
  required CategoryBreakdownRow category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _TagBreakdownSheet(month: month, category: category),
    ),
  );
}

class _TagBreakdownSheet extends ConsumerWidget {
  const _TagBreakdownSheet({required this.month, required this.category});

  final String month;
  final CategoryBreakdownRow category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(
      mobileStatsTagBreakdownProvider((
        month: month,
        categoryId: category.categoryId,
      )),
    );
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${category.categoryName} · 태그별 비율',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(month),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatsDetailActions(month: month, category: category),
          ),
          Expanded(
            child: rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('태그 통계를 불러오지 못했습니다.'),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        mobileStatsTagBreakdownProvider((
                          month: month,
                          categoryId: category.categoryId,
                        )),
                      ),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('선택한 카테고리에 지출 내역이 없습니다.'))
                  : _TagContent(
                      rows: items,
                      onTagTap: (tag) => showMobileTagTransactions(
                        context,
                        month: month,
                        category: category,
                        tag: tag,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagContent extends StatelessWidget {
  const _TagContent({required this.rows, required this.onTagTap});
  final List<TagBreakdownRow> rows;
  final ValueChanged<TagBreakdownRow> onTagTap;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (total > 0)
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 64,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final index =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        if (index >= 0 && index < rows.length) {
                          onTagTap(rows[index]);
                        }
                      },
                    ),
                    sections: [
                      for (final row in rows)
                        PieChartSectionData(
                          value: row.total.toDouble(),
                          color: _tagColor(context, row),
                          radius: 28,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('태그 합계'),
                  const SizedBox(height: 6),
                  Text(
                    formatKRW(total),
                    style: TextStyle(
                      color: context.appExpense,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final row in rows)
          InkWell(
            key: ValueKey('mobile-stats-tag-${row.tagId ?? 'untagged'}'),
            onTap: () => onTagTap(row),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _tagColor(context, row),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.isUntagged ? row.tagName : '#${row.tagName}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${total == 0 ? 0 : (row.total / total * 100).round()}%',
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatKRW(row.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : row.total / total,
                    minHeight: 5,
                    color: _tagColor(context, row),
                    backgroundColor: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Color _tagColor(BuildContext context, TagBreakdownRow row) {
  final value = int.tryParse(row.tagColor.replaceFirst('#', ''), radix: 16);
  return value == null ? context.appAccent : Color(0xFF000000 | value);
}
