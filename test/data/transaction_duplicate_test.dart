import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'copying a transaction draft creates a new row and keeps original',
    () async {
      final accountId = (await db.accountsDao.getActiveAccounts()).first.id;
      final categoryId = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first.id;

      final originalId = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 12000,
          occurredOn: '2025-05-12',
          occurredTime: '18:30',
          accountId: accountId,
          categoryId: categoryId,
          memo: '저녁',
        ),
        tagNames: const ['식비', '복사테스트'],
      );
      final original = (await db.transactionsDao.listTransactionsByMonth(
        '2025-05',
      )).singleWhere((row) => row.id == originalId);

      final copiedId = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: original.type,
          amount: original.amount,
          occurredOn: original.occurredOn,
          occurredTime: original.occurredTime,
          accountId: original.accountId,
          categoryId: original.categoryId,
          fromAccountId: original.fromAccountId,
          toAccountId: original.toAccountId,
          memo: original.memo,
        ),
        tagNames: original.tags.map((tag) => tag.name).toList(),
      );

      expect(copiedId, isNot(originalId));
      final rows = await db.transactionsDao.listTransactionsByMonth('2025-05');
      expect(rows.length, 2);

      final keptOriginal = rows.singleWhere((row) => row.id == originalId);
      final copied = rows.singleWhere((row) => row.id == copiedId);
      expect(keptOriginal.amount, 12000);
      expect(keptOriginal.memo, '저녁');
      expect(copied.amount, keptOriginal.amount);
      expect(copied.occurredTime, keptOriginal.occurredTime);
      expect(copied.tags.map((tag) => tag.name).toSet(), {'식비', '복사테스트'});
    },
  );
}
