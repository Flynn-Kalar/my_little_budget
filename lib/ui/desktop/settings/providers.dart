import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/daos/recurring_dao.dart';
import '../budget/providers.dart' as budget_providers;
import '../stats/providers.dart' as stats_providers;
import '../transactions/providers.dart' as transactions_providers;

final allCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoriesDaoProvider).getAllCategories(),
);

final settingsTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getTags(),
);

final settingsAccountsProvider = FutureProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountsDaoProvider).getActiveAccounts(),
);

final settingsActiveCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>(
      (ref) => ref.watch(categoriesDaoProvider).getActiveCategories(),
    );

final recurringItemsProvider =
    FutureProvider.autoDispose<List<RecurringListItem>>(
      (ref) => ref.watch(recurringDaoProvider).listRecurringTransactions(),
    );

void refreshCategories(WidgetRef ref) {
  ref.invalidate(allCategoriesProvider);
  ref.invalidate(settingsActiveCategoriesProvider);
  ref.invalidate(transactions_providers.activeCategoriesProvider);
  ref.invalidate(budget_providers.budgetExpenseCategoriesProvider);
  ref.invalidate(budget_providers.budgetRowsProvider);
  ref.invalidate(stats_providers.statsExpenseBreakdownProvider);
  ref.invalidate(stats_providers.yearlyExpenseByCategoryProvider);
}

void refreshTags(WidgetRef ref) {
  ref.invalidate(settingsTagsProvider);
  ref.invalidate(transactions_providers.allTagsProvider);
  ref.invalidate(transactions_providers.transactionsListProvider);
}

void refreshRecurring(WidgetRef ref) {
  ref.invalidate(recurringItemsProvider);
  ref.invalidate(transactions_providers.transactionsListProvider);
  ref.invalidate(transactions_providers.monthlySummaryProvider);
}
