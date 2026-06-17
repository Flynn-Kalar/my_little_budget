import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/accounts_dao.dart';
import 'daos/backup_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/investments_dao.dart';
import 'daos/recurring_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/transactions_dao.dart';
import 'seed.dart';
import 'tables/accounts.dart';
import 'tables/budget_groups.dart';
import 'tables/categories.dart';
import 'tables/investments.dart';
import 'tables/monthly_income.dart';
import 'tables/recurring_transactions.dart';
import 'tables/tags.dart';
import 'tables/transactions.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    BudgetGroups,
    BudgetGroupCategories,
    MonthlyIncome,
    Investments,
    RecurringTransactions,
    Tags,
    TransactionTags,
  ],
  daos: [
    AccountsDao,
    TransactionsDao,
    CategoriesDao,
    TagsDao,
    InvestmentsDao,
    RecurringDao,
    BudgetDao,
    BackupDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tags, tags.usageCount);
        await m.addColumn(tags, tags.lastUsedAt);
        await m.addColumn(tags, tags.isPinned);
      }
    },
    beforeOpen: (details) async {
      // SPEC §3 의 외래키 제약을 실제 SQLite 에서 강제하려면 PRAGMA 필요.
      await customStatement('PRAGMA foreign_keys = ON');
      // SPEC §5.3 — 첫 생성 시 기본 자산·카테고리 시드.
      if (details.wasCreated) {
        await seedDefaults(this);
      }
    },
  );

  static QueryExecutor _openConnection() {
    // 모바일·데스크톱 모두: path_provider 의 application documents directory 에 budget.db
    return driftDatabase(name: 'budget');
  }
}
