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

/// SPEC §4.8.5 / §5.2 — 전체 백업 export / import + 전체 초기화.
@DriftAccessor(tables: [
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
])
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  /// 모든 테이블 덤프 → Backup 구조체.
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

  /// 백업 복원. 한 트랜잭션 안에서 모든 테이블 비우고 그대로 다시 삽입.
  /// FK 순서대로 delete → insert. id 포함하여 그대로 (외래키 관계 보존).
  Future<void> importBackup(Backup b) async {
    await transaction(() async {
      // FK 의존 역순으로 delete
      await delete(transactionTags).go();
      await delete(tags).go();
      await delete(investments).go();
      await delete(recurringTransactions).go();
      await delete(transactions).go();
      await delete(monthlyIncome).go();
      await delete(budgetGroupCategories).go();
      await delete(budgetGroups).go();
      await delete(categories).go();
      await delete(accounts).go();

      // 의존 순서대로 insert
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

  /// SPEC §4.8.5 — 전체 초기화.
  ///   - 거래·태그·투자·예산 전부 wipe
  ///   - 카테고리는 기본 시드로 복구
  ///   - 기본 자산 5개는 유지(초기잔액 0 으로 reset), 사용자 추가 자산은 삭제
  Future<void> resetAllData() async {
    await transaction(() async {
      await delete(transactionTags).go();
      await delete(tags).go();
      await delete(investments).go();
      await delete(transactions).go();
      await delete(budgetGroupCategories).go();
      await delete(budgetGroups).go();
      await delete(monthlyIncome).go();

      // 카테고리: 비우고 기본값으로 재생성
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

      // 자산: 기본값 외 삭제, 기본 5개는 upsert (initial=0, 보관 해제).
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
}
