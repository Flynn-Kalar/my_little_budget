import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/categories/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  test('chosen icons survive backup and all transaction query paths', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.categoriesDao.saveCategory(
      draft: const CategoryDraft(
        name: '우리 고양이',
        type: 'expense',
        color: '#ec4899',
        icon: 'pets',
      ),
    );
    final category = (await db.categoriesDao.getAllCategories()).singleWhere(
      (c) => c.name == '우리 고양이',
    );
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final id = await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 3000,
        occurredOn: '2026-10-21',
        occurredTime: '12:00',
        accountId: account.id,
        categoryId: category.id,
        memo: '사료',
      ),
    );
    expect(
      (await db.transactionsDao.getTransactionById(id))!.categoryIcon,
      'pets',
    );
    expect(
      (await db.transactionsDao.listTransactionsByMonth(
        '2026-10',
      )).single.categoryIcon,
      'pets',
    );
    expect(
      (await db.transactionsDao.listTransactionsByAccount(
        account.id,
      )).single.categoryIcon,
      'pets',
    );
    expect(
      (await db.transactionsDao.recentInputEntries()).single.categoryIcon,
      'pets',
    );
    final backup = await db.backupDao.exportBackup();
    final parsed = parseBackup(backup.toJsonString());
    expect(parsed.isOk, isTrue, reason: parsed.error);
    expect(
      parsed.backup!.categories.singleWhere((c) => c.id == category.id).icon,
      'pets',
    );
  });
}
