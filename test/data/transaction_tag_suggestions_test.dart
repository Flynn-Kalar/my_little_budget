import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/tags/suggestion_order.dart';

void main() {
  test(
    'category history ranks first; other tags stay available by overall frequency',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final categories = await db.categoriesDao.getActiveCategories('expense');
      Future<int> save(
        int category,
        List<String> tags, {
        String date = '2026-10-01',
      }) => db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 100,
          occurredOn: date,
          occurredTime: '12:00',
          accountId: account.id,
          categoryId: category,
        ),
        tagNames: tags,
      );
      await save(categories[0].id, ['분류자주']);
      await save(categories[0].id, ['분류자주']);
      await save(categories[0].id, ['분류최근'], date: '2026-10-02');
      await save(categories[0].id, ['분류과거']);
      for (var i = 0; i < 4; i++) {
        await save(categories[1].id, ['전체자주']);
      }
      await db.tagsDao.createTag('미사용', '#64748b');
      Future<List<String>> names([int? id]) async =>
          (await db.tagsDao.getTransactionTagSuggestions(
            categoryId: id,
          )).map((t) => t.name).toList();
      expect(await names(), ['전체자주', '분류자주', '분류최근', '분류과거', '미사용']);
      expect(await names(categories[0].id), [
        '분류자주',
        '분류최근',
        '분류과거',
        '전체자주',
        '미사용',
      ]);
      expect(await names(categories[1].id), [
        '전체자주',
        '분류자주',
        '분류최근',
        '분류과거',
        '미사용',
      ]);
      final deletedId = await save(categories[0].id, ['삭제된거래태그']);
      await db.transactionsDao.deleteTransaction(deletedId);
      expect((await names(categories[0].id)).first, '분류자주');
      expect((await names(categories[0].id)).last, '삭제된거래태그');
    },
  );

  test(
    'locked tag order stays stable across refresh and resets on category change',
    () {
      final order = TagSuggestionOrder();
      expect(order.resolve(['게임', '스팀', '기타'], 1), ['게임', '스팀', '기타']);
      order.lock();
      expect(order.resolve(['기타', '스팀', '게임'], 1), ['게임', '스팀', '기타']);
      expect(order.resolve(['새태그', '기타', '게임', '스팀'], 1), [
        '게임',
        '스팀',
        '기타',
        '새태그',
      ]);
      expect(order.resolve(['기타', '스팀', '게임'], 2), ['기타', '스팀', '게임']);
    },
  );
}
