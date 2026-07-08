import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/daos/accounts_dao.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';

/// 활성 자산 + 계산된 잔액.
final accountBalancesProvider =
    FutureProvider.autoDispose<List<AccountBalance>>(
      (ref) => ref.watch(accountsDaoProvider).getAccountBalances(),
    );

/// 보관된 자산.
final archivedAccountsProvider = FutureProvider.autoDispose<List<Account>>(
  (ref) => ref.watch(accountsDaoProvider).getArchivedAccounts(),
);

/// 단일 자산 + 잔액.
final accountByIdProvider = FutureProvider.autoDispose
    .family<AccountBalance?, int>(
      (ref, id) => ref.watch(accountsDaoProvider).getAccountBalance(id),
    );

/// 자산에 귀속된 거래 (투자 가상 행 병합). SPEC §4.3.
class AccountDetailFilter {
  const AccountDetailFilter({
    this.fromDate,
    this.toDate,
    this.categoryIds = const {},
    this.tagIds = const {},
  });

  final String? fromDate;
  final String? toDate;
  final Set<int> categoryIds;
  final Set<int> tagIds;

  bool get isActive =>
      fromDate != null ||
      toDate != null ||
      categoryIds.isNotEmpty ||
      tagIds.isNotEmpty;

  AccountDetailFilter copyWith({
    Object? fromDate = _sentinel,
    Object? toDate = _sentinel,
    Set<int>? categoryIds,
    Set<int>? tagIds,
  }) {
    return AccountDetailFilter(
      fromDate: fromDate == _sentinel ? this.fromDate : fromDate as String?,
      toDate: toDate == _sentinel ? this.toDate : toDate as String?,
      categoryIds: categoryIds ?? this.categoryIds,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

const _sentinel = Object();

final accountDetailFilterProvider =
    StateProvider.family<AccountDetailFilter, int>(
      (ref, id) => const AccountDetailFilter(),
    );

final accountDetailCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>(
      (ref) => ref.watch(categoriesDaoProvider).getActiveCategories(),
    );

final accountDetailTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getTags(),
);

final accountTransactionsProvider = FutureProvider.autoDispose
    .family<List<TransactionRow>, int>((ref, id) async {
      final filter = ref.watch(accountDetailFilterProvider(id));
      final rows = await ref
          .watch(transactionsDaoProvider)
          .listTransactionsByAccount(id);
      return rows.where((row) {
        if (filter.fromDate != null &&
            row.occurredOn.compareTo(filter.fromDate!) < 0) {
          return false;
        }
        if (filter.toDate != null &&
            row.occurredOn.compareTo(filter.toDate!) > 0) {
          return false;
        }
        if (filter.categoryIds.isNotEmpty) {
          if (row.categoryId == null ||
              !filter.categoryIds.contains(row.categoryId)) {
            return false;
          }
        }
        if (filter.tagIds.isNotEmpty) {
          final tagIds = row.tags.map((tag) => tag.id).toSet();
          if (!filter.tagIds.any(tagIds.contains)) return false;
        }
        return true;
      }).toList();
    });

void refreshAccountsList(WidgetRef ref) {
  ref.invalidate(accountBalancesProvider);
  ref.invalidate(archivedAccountsProvider);
}

void refreshAccountDetail(WidgetRef ref, int accountId) {
  ref.invalidate(accountByIdProvider(accountId));
  ref.invalidate(accountTransactionsProvider(accountId));
  refreshAccountsList(ref);
}
