import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;
  late Account card;
  late Account bank;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    card = accounts.firstWhere((a) => a.kind == 'card');
    bank = accounts.firstWhere((a) => a.kind == 'bank');
  });
  tearDown(() => db.close());

  AccountDraft draft(int closingDay) => AccountDraft(
    name: card.name,
    kind: 'card',
    initialBalance: 0,
    color: card.color,
    excludeFromTotal: false,
    isInvestment: false,
    cardPaymentDay: 1,
    cardClosingDay: closingDay,
    cardPaymentAccountUuid: bank.uuid,
  );
  Future<void> configure(int closingDay) => db.accountsDao.saveAccount(
    id: card.id,
    draft: draft(closingDay),
    currentBalance: 0,
    adjustBalance: false,
  );
  Future<void> expense(String date, int amount) async {
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        occurredOn: date,
        occurredTime: '00:00',
        amount: amount,
        accountId: card.id,
        categoryId: category.id,
      ),
    );
  }

  test(
    'month-end card uses the closing day inclusively instead of global start day',
    () async {
      await configure(31);
      await expense('2026-10-31', 11000);
      await expense('2026-11-01', 20000);
      await expense('2026-11-30', 30000);
      await expense('2026-12-01', 40000);
      final current = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 19),
        statementStart: '2026-10-31',
        statementEnd: '2026-11-29',
      ))!;
      expect(current.cardSpendingStart, '2026-11-01');
      expect(current.cardSpendingEnd, '2026-11-30');
      expect(current.cardSpendingToDate, 20000);
      expect(current.cardMonthSpending, 50000);
      final closing = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 30),
      ))!;
      final next = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 12, 1),
      ))!;
      expect(closing.cardSpendingToDate, 50000);
      expect(next.cardSpendingToDate, 40000);
      final rows = await db.transactionsDao.listTransactionsByAccount(card.id);
      expect(rows.map((r) => r.cardSpendingAfter).toList(), [
        40000,
        50000,
        20000,
        11000,
      ]);
    },
  );

  test(
    '10th stays in the old period and 11th starts fresh including adjustments',
    () async {
      await configure(10);
      await expense('2026-10-10', 1000);
      await expense('2026-10-11', 2000);
      await expense('2026-11-10', 3000);
      await expense('2026-11-11', 4000);
      await expense('2026-12-10', 5000);
      await expense('2026-12-11', 6000);
      final closing = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 10),
      ))!;
      expect(closing.cardSpendingToDate, 5000);
      expect(closing.cardMonthSpending, 5000);
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(10),
        currentBalance: 0,
        currentCardSpending: 4500,
        asOf: DateTime(2026, 11, 10),
      );
      expect(
        (await db.accountsDao.getAccountBalance(
          card.id,
          asOf: DateTime(2026, 11, 10),
        ))!.cardSpendingToDate,
        4500,
      );
      final next = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 11),
      ))!;
      expect(next.cardSpendingToDate, 4000);
      expect(next.cardMonthSpending, 9000);
    },
  );

  test(
    '415191 correction and 403823 unpaid debt remain separately verifiable',
    () async {
      await configure(31);
      await expense('2026-11-18', 431210);
      await expense('2026-11-25', 48000);
      // Synthetic prior credit reproduces the reported difference. Its actual
      // source in the user's ledger is unknown and is not inferred here.
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'transfer',
          occurredOn: '2026-10-31',
          occurredTime: '00:00',
          amount: 11368,
          fromAccountId: bank.id,
          toAccountId: card.id,
        ),
      );
      final today = DateTime(2026, 11, 19);
      final before = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      expect(before.cardSpendingToDate, 431210);
      expect(before.balance, -419842);
      Future<void> correct() => db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(31),
        currentBalance: 0,
        currentCardSpending: 415191,
        asOf: today,
      );
      await correct();
      final after = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      expect(after.cardSpendingToDate, 415191);
      expect(after.cardMonthSpending, 463191);
      expect(after.balance, -403823);
      final rows = await db.transactionsDao.listTransactionsByAccount(card.id);
      final correction = rows.singleWhere((r) => r.type == 'adjustment');
      expect(correction.amount, 16019);
      expect(correction.cardSpendingAfter, 415191);
      expect(correction.balanceAfter, -403823);
      await correct();
      expect(
        (await db.transactionsDao.listTransactionsByAccount(card.id)).length,
        rows.length,
      );
    },
  );

  test(
    'changing cutoff and entered usage compares against the new period',
    () async {
      await configure(31);
      await expense('2026-11-05', 30000);
      await expense('2026-11-11', 10000);
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(10),
        currentBalance: 0,
        currentCardSpending: 20000,
        asOf: DateTime(2026, 11, 19),
      );
      final result = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 19),
      ))!;
      expect(result.cardSpendingStart, '2026-11-11');
      expect(result.cardSpendingToDate, 20000);
      expect(result.balance, -50000);
    },
  );

  test(
    'metadata-only cutoff change does not invent a usage correction',
    () async {
      await configure(31);
      await expense('2026-11-05', 30000);
      await configure(10);
      expect(
        (await db.transactionsDao.listTransactionsByAccount(
          card.id,
        )).single.type,
        'expense',
      );
      expect(
        (await db.accountsDao.getAccountBalance(
          card.id,
          asOf: DateTime(2026, 11, 19),
        ))!.cardSpendingToDate,
        0,
      );
    },
  );
}
