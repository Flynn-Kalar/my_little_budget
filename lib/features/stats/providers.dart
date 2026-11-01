import '../settings/statement_period.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/date.dart';
import '../../data/daos/transactions_dao.dart';
import '../../data/providers.dart';

final statsMonthProvider =
    StateNotifierProvider<StatementMonthController, String>(
      createStatementMonthController,
    );
final statsYearProvider = StateProvider<int>((ref) {
  final policy =
      ref.watch(statementPeriodProvider).asData?.value ??
      const StatementPeriod();
  return int.parse(
    policy
        .displayMonth(ref.watch(currentStatementMonthProvider))
        .substring(0, 4),
  );
});
final statsSelectedCategoryProvider = StateProvider<CategoryBreakdownRow?>(
  (ref) => null,
);
final statsSelectedTagProvider = StateProvider<TagBreakdownRow?>((ref) => null);
final statsDetailPanelOpenProvider = StateProvider<bool>((ref) => false);

final statsExpenseBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdownRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.expenseByCategory(
        month,
        period: (await ref.watch(statementPeriodProvider.future)).range(month),
      );
    });

final statsMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final policy = await ref.watch(statementPeriodProvider.future);
      return _trend(
        dao,
        policy,
        List.generate(12, (i) => shiftMonth(month, i - 11)),
      );
    });

final statsCategoryTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final selected = _effectiveCategory(ref);
      if (selected == null) return const [];
      final month = ref.watch(statsMonthProvider);
      final range = (await ref.watch(
        statementPeriodProvider.future,
      )).range(month);
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
      return dao.expenseByTag(
        month,
        selected.categoryId,
        period: (await ref.watch(statementPeriodProvider.future)).range(month),
      );
    });

final statsTagTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final category = _effectiveCategory(ref);
      if (category == null) return const [];
      final tag = _effectiveTag(ref);
      if (tag == null) return const [];
      final month = ref.watch(statsMonthProvider);
      final range = (await ref.watch(
        statementPeriodProvider.future,
      )).range(month);
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
) async {
  final dao = ref.watch(transactionsDaoProvider);
  final policy = await ref.watch(statementPeriodProvider.future);
  final dates = await dao.transactionDates();
  return dates
      .map(
        (date) => int.parse(
          policy
              .displayMonth(policy.anchorForDate(parseDateKey(date)))
              .substring(0, 4),
        ),
      )
      .toSet()
      .toList()
    ..sort();
});

final yearlyMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final policy = await ref.watch(statementPeriodProvider.future);
      final rows = await _trend(dao, policy, policy.anchorsForYear(year));
      return List.generate(12, (i) {
        final month = '$year-${(i + 1).toString().padLeft(2, '0')}';
        final matching = rows.where((r) => r.month == month);
        return MonthlyTrendRow(
          month: month,
          income: matching.fold(0, (a, b) => a + b.income),
          expense: matching.fold(0, (a, b) => a + b.expense),
        );
      });
    });

final yearlyExpenseByCategoryProvider =
    FutureProvider.autoDispose<List<YearlyPivotRow>>((ref) async {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final policy = await ref.watch(statementPeriodProvider.future);
      final result = <int, YearlyPivotRow>{};
      for (final anchor in policy.anchorsForYear(year)) {
        final monthIndex =
            int.parse(policy.displayMonth(anchor).substring(5)) - 1;
        for (final row in await dao.expenseByCategory(
          anchor,
          period: policy.range(anchor),
        )) {
          final pivot = result.putIfAbsent(
            row.categoryId,
            () => YearlyPivotRow(
              categoryId: row.categoryId,
              categoryName: row.categoryName,
              categoryColor: row.categoryColor,
              months: List.filled(12, 0),
            ),
          );
          pivot.months[monthIndex] += row.total;
        }
      }
      return result.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    });

Future<List<MonthlyTrendRow>> _trend(
  TransactionsDao dao,
  StatementPeriod policy,
  List<String> anchors,
) => Future.wait(
  anchors.map((anchor) async {
    final summary = await dao.monthlySummary(
      anchor,
      period: policy.range(anchor),
    );
    return MonthlyTrendRow(
      month: policy.displayMonth(anchor),
      periodMonth: anchor,
      income: summary.income,
      expense: summary.expense,
    );
  }),
);
