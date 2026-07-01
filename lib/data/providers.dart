import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date.dart';
import 'daos/accounts_dao.dart';
import 'daos/backup_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/investments_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/recurring_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/transactions_dao.dart';
import 'database.dart';

/// 앱 전역 단일 DB 인스턴스. 첫 쿼리 시 lazy open → 시드(beforeOpen).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountsDaoProvider = Provider<AccountsDao>(
  (ref) => ref.watch(appDatabaseProvider).accountsDao,
);

final transactionsDaoProvider = Provider<TransactionsDao>(
  (ref) => ref.watch(appDatabaseProvider).transactionsDao,
);

final categoriesDaoProvider = Provider<CategoriesDao>(
  (ref) => ref.watch(appDatabaseProvider).categoriesDao,
);

final tagsDaoProvider = Provider<TagsDao>(
  (ref) => ref.watch(appDatabaseProvider).tagsDao,
);

final investmentsDaoProvider = Provider<InvestmentsDao>(
  (ref) => ref.watch(appDatabaseProvider).investmentsDao,
);

final recurringDaoProvider = Provider<RecurringDao>(
  (ref) => ref.watch(appDatabaseProvider).recurringDao,
);

final budgetDaoProvider = Provider<BudgetDao>(
  (ref) => ref.watch(appDatabaseProvider).budgetDao,
);

final backupDaoProvider = Provider<BackupDao>(
  (ref) => ref.watch(appDatabaseProvider).backupDao,
);

final notesDaoProvider = Provider<NotesDao>(
  (ref) => ref.watch(appDatabaseProvider).notesDao,
);

/// 앱 시작 시 당월 말까지 반복거래를 한 번 backfill 한다.
final recurringBackfillProvider = FutureProvider<int>((ref) {
  final dao = ref.watch(recurringDaoProvider);
  return dao.generateDueRecurringTransactions(
    monthRange(currentMonthKey()).end,
  );
});
