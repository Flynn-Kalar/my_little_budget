import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/providers.dart';

final mobileStatsTagTransactionsProvider = FutureProvider.autoDispose
    .family<List<TransactionRow>, ({String month, int categoryId, int? tagId})>(
      (ref, key) {
        final range = monthRange(key.month);
        return ref
            .watch(transactionsDaoProvider)
            .listTransactionsByMonth(
              key.month,
              filter: TransactionFilter(
                type: 'expense',
                categoryIds: [key.categoryId],
                tagIds: key.tagId == null ? null : [key.tagId!],
                untaggedOnly: key.tagId == null,
                fromDate: range.start,
                toDate: range.end,
              ),
            );
      },
    );

Future<void> showMobileTagTransactions(
  BuildContext context, {
  required String month,
  required CategoryBreakdownRow category,
  required TagBreakdownRow tag,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.85,
    child: _TagTransactionsSheet(month: month, category: category, tag: tag),
  ),
);

class _TagTransactionsSheet extends ConsumerWidget {
  const _TagTransactionsSheet({
    required this.month,
    required this.category,
    required this.tag,
  });
  final String month;
  final CategoryBreakdownRow category;
  final TagBreakdownRow tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mobileStatsTagTransactionsProvider((
      month: month,
      categoryId: category.categoryId,
      tagId: tag.tagId,
    ));
    final rows = ref.watch(provider);
    final label = tag.isUntagged ? tag.tagName : '#${tag.tagName}';
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 20, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: '태그 비율로 돌아가기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label 거래내역',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('$month · ${category.categoryName}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('거래내역을 불러오지 못했습니다.'),
                    TextButton(
                      onPressed: () => ref.invalidate(provider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('선택한 태그의 지출 내역이 없습니다.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text('${items.length}건')),
                              Text(
                                '합계 ${formatKRW(items.fold<int>(0, (sum, row) => sum + row.amount))}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final row = items[index];
                              return Column(
                                key: ValueKey(
                                  'mobile-stats-transaction-${row.id}',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row.occurredOn} ${row.occurredTime}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row.memo?.trim().isNotEmpty == true
                                              ? row.memo!.trim()
                                              : row.categoryName ?? '거래',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        formatKRW(row.amount),
                                        style: TextStyle(
                                          color: context.appExpense,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(row.accountName ?? '-'),
                                  if (row.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        row.tags
                                            .map((tag) => '#${tag.name}')
                                            .join(' '),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
