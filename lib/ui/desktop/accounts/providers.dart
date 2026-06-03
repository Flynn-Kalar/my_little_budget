import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/daos/accounts_dao.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';

/// 활성 자산 + 계산된 잔액.
final accountBalancesProvider = FutureProvider.autoDispose<List<AccountBalance>>(
  (ref) => ref.watch(accountsDaoProvider).getAccountBalances(),
);

/// 보관된 자산.
final archivedAccountsProvider = FutureProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountsDaoProvider).getArchivedAccounts(),
);

/// 단일 자산 + 잔액.
final accountByIdProvider =
    FutureProvider.autoDispose.family<AccountBalance?, int>(
  (ref, id) => ref.watch(accountsDaoProvider).getAccountBalance(id),
);

/// 자산에 귀속된 거래 (투자 가상 행 병합). SPEC §4.3.
final accountTransactionsProvider =
    FutureProvider.autoDispose.family<List<TransactionRow>, int>(
  (ref, id) => ref.watch(transactionsDaoProvider).listTransactionsByAccount(id),
);

void refreshAccountsList(WidgetRef ref) {
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(archivedAccountsProvider);
}

void refreshAccountDetail(WidgetRef ref, int accountId) {
  ref.invalidate(accountByIdProvider(accountId));
  ref.invalidate(accountTransactionsProvider(accountId));
  refreshAccountsList(ref);
}
