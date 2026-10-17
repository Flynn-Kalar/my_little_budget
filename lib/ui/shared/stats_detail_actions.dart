import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/date.dart';
import '../../data/daos/transactions_dao.dart';
import '../../features/transactions/providers.dart' as transactions;
import '../../features/budget/providers.dart' as budget;

/// Capture the router before dismissing nested mobile sheets.
GoRouter _dismissStatsSheets(BuildContext context) {
  final router = GoRouter.of(context);
  Navigator.of(context).popUntil((route) => route is! PopupRoute);
  return router;
}

void openStatsTransactions(
  BuildContext context,
  WidgetRef ref, {
  required String month,
  CategoryBreakdownRow? category,
  TagBreakdownRow? tag,
}) {
  final range = monthRange(month);
  ref.read(transactions.selectedMonthProvider.notifier).state = month;
  ref.read(transactions.typeFilterProvider.notifier).state = 'expense';
  ref
      .read(transactions.searchFilterProvider.notifier)
      .state = TransactionFilter(
    fromDate: range.start,
    toDate: range.end,
    categoryIds: category == null ? null : [category.categoryId],
    tagIds: tag?.tagId == null || tag!.isUntagged ? null : [tag.tagId!],
    untaggedOnly: tag?.isUntagged ?? false,
  );
  _dismissStatsSheets(context).go('/transactions');
}

void openStatsBudget(
  BuildContext context,
  WidgetRef ref, {
  required String month,
}) {
  ref.read(budget.budgetMonthProvider.notifier).state = month;
  _dismissStatsSheets(context).go('/budget');
}

class StatsDetailActions extends ConsumerWidget {
  const StatsDetailActions({
    super.key,
    required this.month,
    this.category,
    this.tag,
    this.showBudget = true,
  });
  final String month;
  final CategoryBreakdownRow? category;
  final TagBreakdownRow? tag;
  final bool showBudget;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: ValueKey(
          'stats-organize-${category?.categoryId ?? 'month'}-${tag == null
              ? 'all'
              : tag!.isUntagged
              ? 'untagged'
              : tag!.tagId}',
        ),
        onPressed: () => openStatsTransactions(
          context,
          ref,
          month: month,
          category: category,
          tag: tag,
        ),
        icon: const Icon(Icons.edit_note_outlined, size: 18),
        label: Text(
          tag != null
              ? '이 태그의 내역 정리'
              : category != null
              ? '이 카테고리의 내역 정리'
              : '이 달의 지출 내역 정리',
        ),
      ),
      if (showBudget)
        TextButton.icon(
          onPressed: () => openStatsBudget(context, ref, month: month),
          icon: const Icon(Icons.savings_outlined, size: 18),
          label: Text('$month 예산 조정'),
        ),
    ],
  );
}
