import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/date.dart';
import '../../data/daos/transactions_dao.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'package:my_little_budget/features/accounts/providers.dart'
    as accounts_providers;
import 'package:my_little_budget/features/budget/providers.dart'
    as budget_providers;
import 'package:my_little_budget/features/stats/providers.dart'
    as stats_providers;

/// ?댁뿭 ?붾㈃ ?곹깭/議고쉶 provider. DAO쨌?쒖닔濡쒖쭅???몄텧留??쒕떎 (濡쒖쭅 誘몄닔??.

/// ?꾩옱 蹂닿퀬 ?덈뒗 ??(YYYY-MM).
final selectedMonthProvider = StateProvider<String>((ref) => currentMonthKey());

/// ????꾪꽣. null = ?꾩껜(湲곕낯).
final typeFilterProvider = StateProvider<String?>((ref) => null);

/// 寃???몃? ?꾪꽣 (FilterPanel). type ? typeFilterProvider 媛 ?곕줈 愿由?
final searchFilterProvider = StateProvider<TransactionFilter>(
  (ref) => const TransactionFilter(),
);

bool hasActiveTransactionFilter(TransactionFilter filter) {
  return (filter.q?.trim().isNotEmpty ?? false) ||
      filter.minAmount != null ||
      filter.maxAmount != null ||
      filter.accountId != null ||
      (filter.categoryIds?.isNotEmpty ?? false) ||
      (filter.tagIds?.isNotEmpty ?? false) ||
      filter.untaggedOnly ||
      filter.fromDate != null ||
      filter.toDate != null;
}

/// ??+ ????꾪꽣 湲곗? 嫄곕옒 紐⑸줉. backfill ?꾨즺 ??議고쉶.
final transactionsListProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final month = ref.watch(selectedMonthProvider);
      final type = ref.watch(typeFilterProvider);
      final sf = ref.watch(searchFilterProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.listTransactionsByMonth(
        month,
        filter: TransactionFilter(
          type: type,
          q: sf.q,
          minAmount: sf.minAmount,
          maxAmount: sf.maxAmount,
          accountId: sf.accountId,
          categoryIds: sf.categoryIds,
          tagIds: sf.tagIds,
          untaggedOnly: sf.untaggedOnly,
          fromDate: sf.fromDate,
          toDate: sf.toDate,
        ),
      );
    });

/// ???섏엯/吏異??쒖닔??
final monthlySummaryProvider = FutureProvider.autoDispose<MonthlySummary>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  final dao = ref.watch(transactionsDaoProvider);
  return dao.monthlySummary(month);
});

final transactionsMonthRowsProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      final month = ref.watch(selectedMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.listTransactionsByMonth(month);
    });

final transactionsCategoryBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdownRow>>((ref) {
      final month = ref.watch(selectedMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.expenseByCategory(month);
    });

final transactionsMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) {
      final month = ref.watch(selectedMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.monthlyTrend(6, month);
    });

final activeAccountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(accountsDaoProvider).getActiveAccounts(),
);

final activeCategoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(categoriesDaoProvider).getActiveCategories(),
);

final allTagsProvider = FutureProvider<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getTags(),
);

/// SPEC 짠4.1 ??硫붾え ?먮룞?꾩꽦??
final recentMemosProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(transactionsDaoProvider).getRecentMemos(),
);

/// 嫄곕옒 蹂寃???紐⑸줉쨌?붿빟 媛깆떊.
void refreshTransactions(WidgetRef ref) {
  ref.invalidate(transactionsListProvider);
  ref.invalidate(transactionsMonthRowsProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(transactionsCategoryBreakdownProvider);
  ref.invalidate(transactionsMonthlyTrendProvider);
  ref.invalidate(allTagsProvider);
  ref.invalidate(recentMemosProvider);
  ref.invalidate(accounts_providers.accountBalancesProvider);
  budget_providers.refreshBudget(ref);
  ref.invalidate(stats_providers.statsExpenseBreakdownProvider);
  ref.invalidate(stats_providers.statsMonthlyTrendProvider);
  ref.invalidate(stats_providers.availableStatsYearsProvider);
  ref.invalidate(stats_providers.yearlyMonthlyTrendProvider);
  ref.invalidate(stats_providers.yearlyExpenseByCategoryProvider);
}
