import 'package:drift/drift.dart';

import '../backup.dart';
import '../database.dart';
import '../defaults.dart';
import '../tables/accounts.dart';
import '../tables/budget_groups.dart';
import '../tables/categories.dart';
import '../tables/investments.dart';
import '../tables/monthly_income.dart';
import '../tables/recurring_transactions.dart';
import '../tables/tags.dart';
import '../tables/transactions.dart';

part 'backup_dao.g.dart';

/// 전체 백업 export/import 및 데이터 초기화.
@DriftAccessor(
  tables: [
    Accounts,
    Categories,
    BudgetGroups,
    BudgetGroupCategories,
    MonthlyIncome,
    Transactions,
    Investments,
    RecurringTransactions,
    Tags,
    TransactionTags,
  ],
)
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  Future<Backup> exportBackup() async {
    return Backup(
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      accounts: await select(accounts).get(),
      categories: await select(categories).get(),
      budgetGroups: await select(budgetGroups).get(),
      budgetGroupCategories: await select(budgetGroupCategories).get(),
      transactions: await select(transactions).get(),
      investments: await select(investments).get(),
      tags: await select(tags).get(),
      transactionTags: await select(transactionTags).get(),
      monthlyIncome: await select(monthlyIncome).get(),
      recurringTransactions: await select(recurringTransactions).get(),
    );
  }

  Future<void> importBackup(Backup b) async {
    await transaction(() async {
      await _deleteUserData();
      await delete(categories).go();
      await delete(accounts).go();

      await batch((batch) {
        if (b.accounts.isNotEmpty) batch.insertAll(accounts, b.accounts);
        if (b.categories.isNotEmpty) batch.insertAll(categories, b.categories);
        if (b.budgetGroups.isNotEmpty) {
          batch.insertAll(budgetGroups, b.budgetGroups);
        }
        if (b.budgetGroupCategories.isNotEmpty) {
          batch.insertAll(budgetGroupCategories, b.budgetGroupCategories);
        }
        if (b.monthlyIncome.isNotEmpty) {
          batch.insertAll(monthlyIncome, b.monthlyIncome);
        }
        if (b.transactions.isNotEmpty) {
          batch.insertAll(transactions, b.transactions);
        }
        if (b.investments.isNotEmpty) {
          batch.insertAll(investments, b.investments);
        }
        if (b.recurringTransactions.isNotEmpty) {
          batch.insertAll(recurringTransactions, b.recurringTransactions);
        }
        if (b.tags.isNotEmpty) batch.insertAll(tags, b.tags);
        if (b.transactionTags.isNotEmpty) {
          batch.insertAll(transactionTags, b.transactionTags);
        }
      });
    });
  }

  /// 전체 초기화.
  ///
  /// 사용자 데이터는 모두 삭제하고 기본 카테고리/기본 자산은 초기 상태로 복구한다.
  Future<void> resetAllData() async {
    await transaction(() async {
      await _deleteUserData();

      await delete(categories).go();
      await batch((batch) {
        var i = 0;
        for (final c in defaultExpenseCategories) {
          batch.insert(
            categories,
            CategoriesCompanion.insert(
              name: c.name,
              type: 'expense',
              color: Value(c.color),
              sortOrder: Value(i++),
            ),
          );
        }
        i = 0;
        for (final c in defaultIncomeCategories) {
          batch.insert(
            categories,
            CategoriesCompanion.insert(
              name: c.name,
              type: 'income',
              color: Value(c.color),
              sortOrder: Value(i++),
            ),
          );
        }
      });

      final defaultNames = defaultAccounts.map((a) => a.name).toList();
      await (delete(accounts)..where((a) => a.name.isNotIn(defaultNames))).go();
      for (var i = 0; i < defaultAccounts.length; i++) {
        final a = defaultAccounts[i];
        await into(accounts).insert(
          AccountsCompanion.insert(
            name: a.name,
            kind: a.kind,
            color: Value(a.color),
            initialBalance: const Value(0),
            sortOrder: Value(i),
          ),
          onConflict: DoUpdate(
            (_) => AccountsCompanion(
              kind: Value(a.kind),
              color: Value(a.color),
              initialBalance: const Value(0),
              excludeFromTotal: const Value(false),
              isInvestment: const Value(false),
              archivedAt: const Value(null),
              sortOrder: Value(i),
            ),
            target: [accounts.name],
          ),
        );
      }
    });
  }

  Future<void> _deleteUserData() async {
    await delete(transactionTags).go();
    await delete(budgetGroupCategories).go();
    await delete(investments).go();
    await delete(transactions).go();
    await delete(recurringTransactions).go();
    await delete(budgetGroups).go();
    await delete(tags).go();
    await delete(monthlyIncome).go();
  }
}
