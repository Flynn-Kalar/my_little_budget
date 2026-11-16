import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../budget/providers.dart' as budget_providers;
import '../investments/providers.dart' as investments_providers;
import '../settings/providers.dart' as settings_providers;
import '../transactions/providers.dart' as transactions_providers;
import 'providers.dart' as accounts_providers;

void refreshAccountMetadata(WidgetRef ref, {int? accountId}) {
  accounts_providers.refreshAccountsList(ref);
  if (accountId != null) {
    ref.invalidate(accounts_providers.accountByIdProvider(accountId));
    ref.invalidate(accounts_providers.accountTransactionsProvider(accountId));
  }
  ref.invalidate(transactions_providers.activeAccountsProvider);
  ref.invalidate(budget_providers.budgetActiveAccountsProvider);
  ref.invalidate(budget_providers.budgetRowsProvider);
  ref.invalidate(investments_providers.investmentAccountProvider);
  ref.invalidate(settings_providers.settingsAccountsProvider);
}

void refreshAccountTransactionMutation(WidgetRef ref, int accountId) {
  accounts_providers.refreshAccountDetail(ref, accountId);
  transactions_providers.refreshTransactions(ref);
}
