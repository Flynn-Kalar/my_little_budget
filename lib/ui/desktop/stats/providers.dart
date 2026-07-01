import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/providers.dart';

final statsMonthProvider = StateProvider<String>((ref) => currentMonthKey());
final statsYearProvider = StateProvider<int>((ref) => DateTime.now().year);
final statsSelectedCategoryProvider = StateProvider<CategoryBreakdownRow?>(
  (ref) => null,
);
final statsSelectedTagProvider = StateProvider<TagBreakdownRow?>((ref) => null);
final statsDetailPanelOpenProvider = StateProvider<bool>((ref) => false);

final statsExpenseBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdownRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.expenseByCategory(month);
    });

final statsMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.monthlyTrend(12, month);
    });

final statsCategoryTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final selected = _effectiveCategory(ref);
      if (selected == null) return const [];
      final month = ref.watch(statsMonthProvider);
      final range = monthRange(month);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.listTransactionsByMonth(
        month,
        filter: TransactionFilter(
          type: 'expense',
          categoryIds: [selected.categoryId],
          fromDate: range.start,
          toDate: range.end,
        ),
      );
    });

final statsTagBreakdownProvider =
    FutureProvider.autoDispose<List<TagBreakdownRow>>((ref) async {
      final selected = _effectiveCategory(ref);
      if (selected == null) return const [];
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.expenseByTag(month, selected.categoryId);
    });

final statsTagTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final category = _effectiveCategory(ref);
      if (category == null) return const [];
      final tag = _effectiveTag(ref);
      if (tag == null) return const [];
      final month = ref.watch(statsMonthProvider);
      final range = monthRange(month);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.listTransactionsByMonth(
        month,
        filter: TransactionFilter(
          type: 'expense',
          categoryIds: [category.categoryId],
          tagIds: tag.tagId == null ? null : [tag.tagId!],
          untaggedOnly: tag.isUntagged,
          fromDate: range.start,
          toDate: range.end,
        ),
      );
    });

CategoryBreakdownRow? _effectiveCategory(Ref ref) {
  final selected = ref.watch(statsSelectedCategoryProvider);
  if (selected != null) return selected;
  final rows = ref.watch(statsExpenseBreakdownProvider).asData?.value;
  if (rows == null || rows.isEmpty) return null;
  return rows.first;
}

TagBreakdownRow? _effectiveTag(Ref ref) {
  final selected = ref.watch(statsSelectedTagProvider);
  final rows = ref.watch(statsTagBreakdownProvider).asData?.value;
  if (rows == null || rows.isEmpty) return null;
  if (selected == null) return rows.first;
  for (final row in rows) {
    if (row.isUntagged == selected.isUntagged && row.tagId == selected.tagId) {
      return row;
    }
  }
  return rows.first;
}

final availableStatsYearsProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) {
  final dao = ref.watch(transactionsDaoProvider);
  return dao.availableTransactionYears();
});

final yearlyMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.monthlyTrend(12, '$year-12');
    });

final yearlyExpenseByCategoryProvider =
    FutureProvider.autoDispose<List<YearlyPivotRow>>((ref) {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.yearlyCategoryPivot(year, 'expense');
    });
