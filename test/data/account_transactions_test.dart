import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('listTransactionsByAccount (SPEC §4.3)', () {
    test('일반 거래 + 투자 가상 행 병합, 최신순', () async {
      final accts = await db.accountsDao.getActiveAccounts();
      final mainAcc = accts.first; // 주거래
      final invAcc = accts.firstWhere((a) => a.name == '투자');
      final catId =
          (await db.categoriesDao.getActiveCategories('expense')).first.id;

      // 일반 거래 1개
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 5000,
          occurredOn: '2026-05-10',
          occurredTime: '12:00',
          accountId: mainAcc.id,
          categoryId: catId,
        ),
      );

      // 투자 자산 활성화 + 매수/매도
      await db.accountsDao.saveAccount(
        id: invAcc.id,
        draft: AccountDraft(
          name: invAcc.name,
          kind: invAcc.kind,
          initialBalance: 0,
          color: invAcc.color,
          excludeFromTotal: false,
          isInvestment: true,
        ),
        currentBalance: 0,
      );
      await db.investmentsDao.saveInvestment(
        draft: validateInvestment(
          side: 'buy', occurredOn: '2026-05-01', occurredTime: '09:00',
          ticker: 'AAPL', quantity: 10, totalAmount: 100000,
        ).value!,
      );
      await db.investmentsDao.saveInvestment(
        draft: validateInvestment(
          side: 'sell', occurredOn: '2026-05-15', occurredTime: '09:00',
          ticker: 'AAPL', quantity: 4, totalAmount: 50000,
        ).value!,
      );

      // 일반 자산 상세: 일반 거래 1개만, 투자 가상 행은 0개
      final mainRows =
          await db.transactionsDao.listTransactionsByAccount(mainAcc.id);
      expect(mainRows.length, 1);
      expect(mainRows.first.source, isNull);

      // 투자 자산 상세: buy(가상) + sell(가상) = 2개, 매도 행은 source=investment
      final invRows =
          await db.transactionsDao.listTransactionsByAccount(invAcc.id);
      expect(invRows.length, 2);
      expect(invRows.every((r) => r.source == 'investment'), true);

      // 정렬: 5/15 sell 이 5/1 buy 보다 먼저
      expect(invRows.first.occurredOn, '2026-05-15');
      expect(invRows.first.investmentSide, 'sell');
      // 매도 실현손익 = 50000 - round(10000 * 4) = 10000 → income 색
      expect(invRows.first.type, 'income');
      expect(invRows.first.amount, 10000);
      expect(invRows.first.balanceImpact, 10000);
    });
  });

  group('getRecentMemos (SPEC §4.1)', () {
    test('최근 거래의 distinct trim memo', () async {
      final accId = (await db.accountsDao.getActiveAccounts()).first.id;
      final catId =
          (await db.categoriesDao.getActiveCategories('expense')).first.id;
      Future<void> add(String memo, String on) =>
          db.transactionsDao.saveTransaction(
            draft: TransactionDraft(
              type: 'expense',
              amount: 100,
              occurredOn: on,
              occurredTime: '00:00',
              accountId: accId,
              categoryId: catId,
              memo: memo,
            ),
          );
      await add('점심', '2026-05-01');
      await add('  점심  ', '2026-05-02'); // 같은 메모(trim)
      await add('카페', '2026-05-03');
      await add('점심', '2026-05-04');

      final memos = await db.transactionsDao.getRecentMemos();
      // distinct: 카페, 점심 (최신순). 점심이 더 최근(id 더 큼).
      expect(memos.length, 2);
      expect(memos.first, '점심');
      expect(memos.last, '카페');
    });
  });
}
