import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../accounts/providers.dart' as accounts_providers;
import '../budget/providers.dart' as budget_providers;
import '../stats/providers.dart' as stats_providers;

/// 내역 화면 상태/조회 provider. DAO·순수로직을 호출만 한다 (로직 미수정).

/// 현재 보고 있는 월 (YYYY-MM).
final selectedMonthProvider = StateProvider<String>((ref) => currentMonthKey());

/// 타입 필터. null = 전체. (상단 칩)
final typeFilterProvider = StateProvider<String?>((ref) => null);

/// 검색/세부 필터 (FilterPanel). type 은 typeFilterProvider 가 따로 관리.
final searchFilterProvider = StateProvider<TransactionFilter>(
  (ref) => const TransactionFilter(),
);

/// SPEC §4.1 — 진입 시 이번 달 말일까지 반복거래 backfill (1회, 캐시).
final _recurringBackfillProvider = FutureProvider<int>((ref) async {
  final dao = ref.read(recurringDaoProvider);
  return dao.generateDueRecurringTransactions(
    monthRange(currentMonthKey()).end,
  );
});

/// 월 + 타입 필터 기준 거래 목록. backfill 완료 후 조회.
final transactionsListProvider =
    FutureProvider.autoDispose<List<TransactionRow>>((ref) async {
      await ref.watch(_recurringBackfillProvider.future);
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

/// 월 수입/지출/순수입.
final monthlySummaryProvider = FutureProvider.autoDispose<MonthlySummary>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  final dao = ref.watch(transactionsDaoProvider);
  return dao.monthlySummary(month);
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

/// SPEC §4.1 — 메모 자동완성용.
final recentMemosProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(transactionsDaoProvider).getRecentMemos(),
);

/// 거래 변경 후 목록·요약 갱신.
void refreshTransactions(WidgetRef ref) {
  ref.invalidate(transactionsListProvider);
  ref.invalidate(monthlySummaryProvider);
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
