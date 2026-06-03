import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../data/daos/recurring_dao.dart';

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
}

void refreshTags(WidgetRef ref) {
  ref.invalidate(settingsTagsProvider);
}

void refreshRecurring(WidgetRef ref) {
  ref.invalidate(recurringItemsProvider);
}
