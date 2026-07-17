import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounts/providers.dart' as accounts;
import '../budget/badges_providers.dart' as badges;
import '../budget/providers.dart' as budget;
import '../investments/providers.dart' as investments;
import '../settings/providers.dart' as settings;
import '../stats/providers.dart' as stats;
import '../transactions/providers.dart' as transactions;

/// FutureProviders do not react to raw Drift writes. Call this after a remote
/// pull so an already-open screen observes the newly applied rows.
void invalidateSyncedData(WidgetRef ref) {
  ref.invalidate(accounts.accountBalancesProvider);
  ref.invalidate(accounts.archivedAccountsProvider);
  ref.invalidate(accounts.accountByIdProvider);
  ref.invalidate(accounts.accountTransactionsProvider);

  ref.invalidate(budget.monthlyExpectedIncomeProvider);
  ref.invalidate(budget.budgetRowsProvider);
  ref.invalidate(budget.budgetExpenseCategoriesProvider);
  ref.invalidate(budget.budgetActiveAccountsProvider);
  ref.invalidate(badges.overBudgetCountProvider);

  ref.invalidate(transactions.transactionsListProvider);
  ref.invalidate(transactions.monthlySummaryProvider);
  ref.invalidate(transactions.transactionsMonthRowsProvider);
  ref.invalidate(transactions.transactionsCategoryBreakdownProvider);
  ref.invalidate(transactions.transactionsMonthlyTrendProvider);
  ref.invalidate(transactions.activeAccountsProvider);
  ref.invalidate(transactions.activeCategoriesProvider);
  ref.invalidate(transactions.allTagsProvider);
  ref.invalidate(transactions.recentMemosProvider);

  ref.invalidate(investments.investmentRowsProvider);
  ref.invalidate(investments.investmentMonthlySummaryProvider);
  ref.invalidate(investments.investmentYearlyRowsProvider);
  ref.invalidate(investments.investmentAccountProvider);
  ref.invalidate(investments.currentHoldingsProvider);
  ref.invalidate(investments.realizedPnlProvider);

  ref.invalidate(stats.statsExpenseBreakdownProvider);
  ref.invalidate(stats.statsMonthlyTrendProvider);
  ref.invalidate(stats.statsCategoryTransactionsProvider);
  ref.invalidate(stats.statsTagBreakdownProvider);
  ref.invalidate(stats.statsTagTransactionsProvider);
  ref.invalidate(stats.availableStatsYearsProvider);

  ref.invalidate(settings.allCategoriesProvider);
  ref.invalidate(settings.settingsActiveCategoriesProvider);
  ref.invalidate(settings.settingsAccountsProvider);
  ref.invalidate(settings.settingsTagsProvider);
  ref.invalidate(settings.recurringItemsProvider);
}
