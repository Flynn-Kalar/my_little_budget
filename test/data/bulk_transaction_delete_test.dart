import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;
  late List<int> ids;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    ids = [];
    for (final type in ['expense', 'income', 'transfer', 'expense']) {
      final category = type == 'transfer'
          ? null
          : (await db.categoriesDao.getActiveCategories(type)).first.id;
      ids.add(
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: type,
            amount: 1000,
            occurredOn: '2026-10-01',
            occurredTime: '12:00',
            categoryId: category,
            accountId: type == 'transfer' ? null : accounts.first.id,
            fromAccountId: type == 'transfer' ? accounts.first.id : null,
            toAccountId: type == 'transfer' ? accounts[1].id : null,
          ),
          tagNames: type == 'transfer' ? [] : ['공통'],
        ),
      );
    }
  });
  tearDown(() => db.close());

  test(
    'bulk delete removes only selected rows and tag links and records sync deletes',
    () async {
      final selected = ids.take(3).toSet();
      await db.transactionsDao.bulkDeleteTransactions(ids: selected);
      for (final id in selected) {
        expect(await db.transactionsDao.getTransactionById(id), isNull);
        expect(await db.transactionsDao.getTransactionTags(id), isEmpty);
      }
      expect(await db.transactionsDao.getTransactionById(ids.last), isNotNull);
      expect(
        (await db.transactionsDao.getTransactionTags(ids.last)).single.name,
        '공통',
      );
      final deletes = await db
          .customSelect(
            "SELECT COUNT(*) AS count FROM sync_outbox WHERE entity = 'transactions' AND operation = 'delete'",
          )
          .getSingle();
      expect(deletes.read<int>('count'), 3);
    },
  );

  test('stale selection fails without deleting valid selected rows', () async {
    await expectLater(
      db.transactionsDao.bulkDeleteTransactions(ids: {ids.first, 999999}),
      throwsStateError,
    );
    expect(await db.transactionsDao.getTransactionById(ids.first), isNotNull);
    expect(await db.transactionsDao.getTransactionTags(ids.first), isNotEmpty);
  });

  test(
    'database failure rolls back deletion, tag cascades and sync outbox',
    () async {
      await db.customStatement(
        '''CREATE TRIGGER fail_bulk_delete BEFORE DELETE ON transactions
      WHEN OLD.id = ${ids[1]} BEGIN SELECT RAISE(ABORT, 'test failure'); END''',
      );
      await expectLater(
        db.transactionsDao.bulkDeleteTransactions(ids: ids.take(2).toSet()),
        throwsA(anything),
      );
      for (final id in ids.take(2)) {
        expect(await db.transactionsDao.getTransactionById(id), isNotNull);
        expect(await db.transactionsDao.getTransactionTags(id), isNotEmpty);
      }
      final deletes = await db
          .customSelect(
            "SELECT COUNT(*) AS count FROM sync_outbox WHERE operation = 'delete'",
          )
          .getSingle();
      expect(deletes.read<int>('count'), 0);
    },
  );

  test('empty selection is rejected', () async {
    await expectLater(
      db.transactionsDao.bulkDeleteTransactions(ids: {}),
      throwsArgumentError,
    );
  });
}
