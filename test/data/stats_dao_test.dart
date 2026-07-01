import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> accountId() async =>
      (await db.accountsDao.getActiveAccounts()).first.id;
  Future<int> expenseCat([int idx = 0]) async =>
      (await db.categoriesDao.getActiveCategories('expense'))[idx].id;
  Future<int> incomeCat([int idx = 0]) async =>
      (await db.categoriesDao.getActiveCategories('income'))[idx].id;

  Future<void> addExpense(
    int catId,
    int amount,
    String on, {
    List<String> tagNames = const [],
  }) async {
    final accId = await accountId();
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: amount,
        occurredOn: on,
        occurredTime: '00:00',
        accountId: accId,
        categoryId: catId,
      ),
      tagNames: tagNames,
    );
  }

  Future<void> addIncome(int catId, int amount, String on) async {
    final accId = await accountId();
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'income',
        amount: amount,
        occurredOn: on,
        occurredTime: '00:00',
        accountId: accId,
        categoryId: catId,
      ),
    );
  }

  group('expenseByCategory (SPEC §4.5)', () {
    test('월 지출을 카테고리별로 합산, 합계 내림차순', () async {
      final c1 = await expenseCat(0);
      final c2 = await expenseCat(1);
      await addExpense(c1, 5000, '2026-05-01');
      await addExpense(c1, 3000, '2026-05-10');
      await addExpense(c2, 10000, '2026-05-15');

      final rows = await db.transactionsDao.expenseByCategory('2026-05');
      expect(rows.length, 2);
      expect(rows.first.categoryId, c2);
      expect(rows.first.total, 10000);
      expect(rows.last.categoryId, c1);
      expect(rows.last.total, 8000);
    });
  });

  group('expenseByTag', () {
    test(
      'uses tag order priority for transactions with multiple tags',
      () async {
        final c1 = await expenseCat(0);
        final c2 = await expenseCat(1);
        await addExpense(c1, 5000, '2026-05-02', tagNames: const ['beta']);
        await addExpense(
          c1,
          10000,
          '2026-05-01',
          tagNames: const ['beta', 'alpha'],
        );
        await addExpense(c1, 3000, '2026-05-03');
        await addExpense(c1, 9000, '2026-04-01', tagNames: const ['alpha']);
        await addExpense(c2, 7000, '2026-05-01', tagNames: const ['alpha']);
        final tags = await db.tagsDao.getTags();
        final alphaId = tags.singleWhere((tag) => tag.name == 'alpha').id;
        final betaId = tags.singleWhere((tag) => tag.name == 'beta').id;
        await db.tagsDao.updateTagOrder([alphaId, betaId]);

        final rows = await db.transactionsDao.expenseByTag('2026-05', c1);
        final byName = {for (final row in rows) row.tagName: row};

        expect(byName['alpha']!.total, 10000);
        expect(byName['beta']!.total, 5000);
        expect(byName['태그 없음']!.total, 3000);
        expect(byName['태그 없음']!.isUntagged, isTrue);
        expect(rows.fold<int>(0, (sum, row) => sum + row.total), 18000);
      },
    );
  });

  group('monthlyTrend (SPEC §4.5)', () {
    test('지정 anchor 월부터 거꾸로 n개월, 거래 없는 달은 0', () async {
      final c = await expenseCat();
      final i = await incomeCat();
      await addExpense(c, 5000, '2026-03-15');
      await addIncome(i, 10000, '2026-04-01');
      await addExpense(c, 2000, '2026-05-20');

      final rows = await db.transactionsDao.monthlyTrend(4, '2026-05');
      expect(rows.length, 4);
      expect(rows.map((r) => r.month).toList(), [
        '2026-02',
        '2026-03',
        '2026-04',
        '2026-05',
      ]);
      expect(rows[0].income, 0);
      expect(rows[0].expense, 0);
      expect(rows[1].expense, 5000);
      expect(rows[2].income, 10000);
      expect(rows[3].expense, 2000);
      expect(rows[3].net, -2000);
    });
  });

  group('yearlyCategoryPivot (SPEC §4.6)', () {
    test('카테고리×월 12칸, 사용 카테고리만 포함, 총액 내림차순', () async {
      final c1 = await expenseCat(0);
      final c2 = await expenseCat(1);
      await addExpense(c1, 5000, '2026-02-10'); // 2월
      await addExpense(c1, 3000, '2026-05-20'); // 5월
      await addExpense(c2, 20000, '2026-07-01'); // 7월

      final rows = await db.transactionsDao.yearlyCategoryPivot(
        2026,
        'expense',
      );
      expect(rows.length, 2);
      // 총액 큰 게 먼저
      expect(rows.first.categoryId, c2);
      expect(rows.first.months[6], 20000); // 7월 = idx 6
      expect(rows.last.categoryId, c1);
      expect(rows.last.months[1], 5000); // 2월
      expect(rows.last.months[4], 3000); // 5월
      expect(rows.last.total, 8000);
    });
  });

  group('availableTransactionYears', () {
    test('거래 있는 연도만 정렬 반환', () async {
      final c = await expenseCat();
      await addExpense(c, 100, '2024-01-01');
      await addExpense(c, 100, '2026-06-01');
      expect(await db.transactionsDao.availableTransactionYears(), [
        2024,
        2026,
      ]);
    });
  });
}
