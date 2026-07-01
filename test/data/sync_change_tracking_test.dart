import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/sync_metadata.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> markSynced(String table, int id) {
    return db.customUpdate(
      "UPDATE $table SET sync_status = 'synced' WHERE id = ?",
      variables: [Variable<int>(id)],
    );
  }

  Future<String> statusOf(String table, int id) async {
    final row = await db
        .customSelect(
          'SELECT sync_status FROM $table WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingle();
    return row.read<String>('sync_status');
  }

  test('editing an entity marks it pending again', () async {
    final account = (await db.accountsDao.getActiveAccounts()).first;
    await markSynced('accounts', account.id);

    await db.accountsDao.archiveAccount(account.id);

    expect(await statusOf('accounts', account.id), syncStatusPending);
  });

  test(
    'transaction tag mapping change marks parent transaction pending',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final transactionId = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 1000,
          occurredOn: '2026-06-21',
          occurredTime: '12:00',
          accountId: account.id,
          categoryId: category.id,
        ),
      );
      final tagId = await db.tagsDao.createTag('동기화', '#123456');
      await markSynced('transactions', transactionId);

      await db.tagsDao.setTransactionTags(transactionId, [tagId]);

      expect(await statusOf('transactions', transactionId), syncStatusPending);
    },
  );

  test('budget category mapping change marks parent group pending', () async {
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    final groupId = await db.budgetDao.createBudgetGroup(
      name: '생활비',
      month: '2026-06',
      amount: 100000,
    );
    await markSynced('budget_groups', groupId);

    await db.budgetDao.addCategoryToGroup(groupId, category.id);

    expect(await statusOf('budget_groups', groupId), syncStatusPending);
  });

  test('deletes remain hard deletes', () async {
    final tagId = await db.tagsDao.createTag('삭제', '#123456');

    await db.tagsDao.deleteTag(tagId);

    final row = await db
        .customSelect(
          'SELECT id FROM tags WHERE id = ?',
          variables: [Variable<int>(tagId)],
        )
        .getSingleOrNull();
    expect(row, null);
  });
}
