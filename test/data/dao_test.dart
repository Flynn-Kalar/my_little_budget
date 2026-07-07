import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> firstAccountId() async =>
      (await db.accountsDao.getActiveAccounts()).first.id;
  Future<int> firstExpenseCategoryId() async =>
      (await db.categoriesDao.getActiveCategories('expense')).first.id;
  Future<int> firstIncomeCategoryId() async =>
      (await db.categoriesDao.getActiveCategories('income')).first.id;

  group('seed (SPEC §5.3)', () {
    test('첫 생성 시 기본 자산 5개 + 카테고리 14개', () async {
      final accts = await db.accountsDao.getActiveAccounts();
      final cats = await db.categoriesDao.getAllCategories();
      expect(accts.length, 5);
      expect(cats.length, 14);
      expect(accts.where((a) => a.isInvestment).length, 1);
      expect(accts.firstWhere((a) => a.name == '투자').isInvestment, true);
      expect(cats.where((c) => c.type == 'expense').length, 10);
      expect(cats.where((c) => c.type == 'income').length, 4);
    });
  });

  group('transactions + 잔액 (SPEC §3.9 / §4.1)', () {
    test('지출 저장 → 월 요약·잔액 반영', () async {
      final accId = await firstAccountId();
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 5000,
          occurredOn: '2025-05-10',
          occurredTime: '12:00',
          accountId: accId,
          categoryId: await firstExpenseCategoryId(),
        ),
      );

      final summary = await db.transactionsDao.monthlySummary('2025-05');
      expect(summary.expense, 5000);
      expect(summary.income, 0);

      final bal = await db.accountsDao.getAccountBalance(accId);
      expect(bal!.balance, -5000);

      final rows = await db.transactionsDao.listTransactionsByMonth('2025-05');
      expect(rows.length, 1);
      expect(rows.first.categoryName, isNotNull);
    });

    test('다른 달 거래는 월 목록에서 제외', () async {
      final accId = await firstAccountId();
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'income',
          amount: 1000,
          occurredOn: '2025-04-01',
          occurredTime: '00:00',
          accountId: accId,
          categoryId: await firstIncomeCategoryId(),
        ),
      );
      expect(
        await db.transactionsDao.listTransactionsByMonth('2025-05'),
        isEmpty,
      );
      expect(
        (await db.transactionsDao.listTransactionsByMonth('2025-04')).length,
        1,
      );
    });
  });

  group('saveAccount — 편집 시 잔액차이는 adjustment (SPEC §4.2)', () {
    test('현재잔액 변경 → adjustment 거래로 보정', () async {
      final acc = (await db.accountsDao.getActiveAccounts()).first;
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 5000,
          occurredOn: '2025-05-10',
          occurredTime: '00:00',
          accountId: acc.id,
          categoryId: await firstExpenseCategoryId(),
        ),
      );
      await db.accountsDao.saveAccount(
        id: acc.id,
        draft: AccountDraft(
          name: acc.name,
          kind: acc.kind,
          initialBalance: 0,
          color: acc.color,
          excludeFromTotal: false,
          isInvestment: false,
        ),
        currentBalance: 10000,
      );

      final bal = await db.accountsDao.getAccountBalance(acc.id);
      expect(bal!.balance, 10000);
      expect(bal.initialBalance, 0);
    });
  });

  group('card limit warning', () {
    test(
      'manual card limit warns when current card debt reaches 80%',
      () async {
        final card = (await db.accountsDao.getActiveAccounts()).firstWhere(
          (account) => account.kind == 'card',
        );
        await db.accountsDao.saveAccount(
          id: card.id,
          draft: AccountDraft(
            name: card.name,
            kind: card.kind,
            initialBalance: card.initialBalance,
            cardLimit: 100000,
            color: card.color,
            excludeFromTotal: card.excludeFromTotal,
            isInvestment: card.isInvestment,
          ),
          currentBalance: -79000,
        );

        final categoryId = await firstExpenseCategoryId();
        final firstDraft = TransactionDraft(
          type: 'expense',
          amount: 500,
          occurredOn: '2026-07-03',
          occurredTime: '00:00',
          accountId: card.id,
          categoryId: categoryId,
        );
        await db.transactionsDao.saveTransaction(draft: firstDraft);
        expect(
          await db.transactionsDao.cardLimitWarningFor(firstDraft),
          isNull,
        );

        final secondDraft = TransactionDraft(
          type: 'expense',
          amount: 500,
          occurredOn: '2026-07-04',
          occurredTime: '00:00',
          accountId: card.id,
          categoryId: categoryId,
        );
        await db.transactionsDao.saveTransaction(draft: secondDraft);
        final warning = await db.transactionsDao.cardLimitWarningFor(
          secondDraft,
        );

        expect(warning, isNotNull);
        expect(warning!.accountId, card.id);
        expect(warning.limit, 100000);
        expect(warning.used, 80000);
        expect(warning.remaining, 20000);
        expect(warning.exceeded, isFalse);
      },
    );
  });

  group('isInvestment 단일 보장 (SPEC §3.1)', () {
    test('새 투자 자산 지정 시 기존 투자 자산 해제', () async {
      final accts = await db.accountsDao.getActiveAccounts();
      final a = accts[0];
      final b = accts[1];

      for (final acc in [a, b]) {
        await db.accountsDao.saveAccount(
          id: acc.id,
          draft: AccountDraft(
            name: acc.name,
            kind: acc.kind,
            initialBalance: 0,
            color: acc.color,
            excludeFromTotal: false,
            isInvestment: true,
          ),
          currentBalance: 0,
        );
      }

      final balances = await db.accountsDao.getAccountBalances();
      expect(balances.where((x) => x.isInvestment).length, 1);
      expect(
        balances.firstWhere((x) => x.accountId == b.id).isInvestment,
        true,
      );
    });
  });

  group('태그 by name (SPEC §4.1)', () {
    test('신규 태그 자동 생성 + 매핑, 중복 제거', () async {
      final accId = await firstAccountId();
      final txId = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 3000,
          occurredOn: '2025-05-10',
          occurredTime: '00:00',
          accountId: accId,
          categoryId: await firstExpenseCategoryId(),
        ),
        tagNames: ['여행', '맛집', '여행'],
      );

      final tags = await db.transactionsDao.getTransactionTags(txId);
      expect(tags.length, 2);
      expect(tags.map((t) => t.name).toSet(), {'여행', '맛집'});
    });
  });

  group('usage count / 삭제 가드 (SPEC §4.2)', () {
    test('거래가 있는 자산은 삭제 거부', () async {
      final accId = await firstAccountId();
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 1000,
          occurredOn: '2025-05-10',
          occurredTime: '00:00',
          accountId: accId,
          categoryId: await firstExpenseCategoryId(),
        ),
      );
      expect(await db.accountsDao.getAccountUsageCount(accId), greaterThan(0));
      expect(await db.accountsDao.deleteAccount(accId), isNotNull);
    });
  });
}
