import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/budget/entry_preview.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;
  late int account;
  late int category;
  late int otherCategory;
  const policy = StatementPeriod(day: 25, labelByEnd: true);
  final period = policy.range('2026-10');

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    account = (await db.accountsDao.getActiveAccounts()).first.id;
    final cats = await db.categoriesDao.getActiveCategories('expense');
    category = cats[0].id;
    otherCategory = cats[1].id;
  });
  tearDown(() => db.close());

  TransactionDraft expense(
    int amount, {
    String date = '2026-11-17',
    int? cat,
  }) => TransactionDraft(
    type: 'expense',
    amount: amount,
    occurredOn: date,
    occurredTime: '12:00',
    accountId: account,
    categoryId: cat ?? category,
  );

  Future<int> budget(String name, int amount, {int? cat, int? percentage}) =>
      db.budgetDao.createBudgetGroup(
        name: name,
        month: '2026-10',
        amount: amount,
        categoryIds: [cat ?? category],
        percentage: percentage,
      );

  test(
    'custom statement period, scheduled expense, edit vs copy and no write',
    () async {
      await budget('식비', 100000);
      await db.transactionsDao.saveTransaction(
        draft: expense(90000, date: '2026-10-24'),
      );
      final original = await db.transactionsDao.saveTransaction(
        draft: expense(20000),
      );
      await db.transactionsDao.saveTransaction(
        draft: expense(10000, date: '2026-11-24'),
      );
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
        excludingTransactionId: original,
      );
      final preview = previewEntryBudgets(
        rows: rows,
        draft: expense(60000),
        policy: policy,
        today: DateTime(2026, 11, 17),
      ).single;
      expect(preview.before, 90000);
      expect(preview.remaining, 30000);
      expect(preview.allowance!.days, 8);
      expect(preview.allowance!.daily, 3750);
      final actual = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      expect(actual.single.spentAmount, 30000);
      expect(
        previewEntryBudgets(
          rows: actual,
          draft: expense(60000),
          policy: policy,
          today: DateTime(2026, 11, 17),
        ).single.remaining,
        10000,
      );
      expect(
        (await db.transactionsDao.getTransactionById(original))!.amount,
        20000,
      );
    },
  );

  test(
    'overlapping groups stay separate; past and future daily guidance',
    () async {
      await budget('식비', 100000);
      await budget('생활비', 50000);
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      final previews = previewEntryBudgets(
        rows: rows,
        draft: expense(60000),
        policy: policy,
        today: DateTime(2026, 11, 25),
      );
      expect(previews.map((p) => p.remaining), [40000, -10000]);
      expect(previews.every((p) => p.allowance == null), isTrue);
      expect(
        previewEntryBudgets(
          rows: rows,
          draft: expense(60000),
          policy: policy,
          today: DateTime(2026, 10, 1),
        ).first.allowance!.days,
        31,
      );
      expect(
        previewEntryBudgets(
          rows: rows,
          draft: expense(0),
          policy: policy,
          today: DateTime(2026, 10, 1),
        ),
        isEmpty,
      );
    },
  );

  test(
    'account budgets exclude original before and within the selected period',
    () async {
      await db.budgetDao.createBudgetGroup(
        name: '자산',
        month: '2026-10',
        amount: 0,
        accountId: account,
      );
      final incomeCat = (await db.categoriesDao.getActiveCategories(
        'income',
      )).first.id;
      final original = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'income',
          amount: 100000,
          occurredOn: '2026-10-20',
          occurredTime: '12:00',
          accountId: account,
          categoryId: incomeCat,
        ),
      );
      final before = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      final without = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
        excludingTransactionId: original,
      );
      expect(before.single.budgetAmount - without.single.budgetAmount, 100000);
      final outgoing = await db.transactionsDao.saveTransaction(
        draft: expense(20000),
      );
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
        excludingTransactionId: outgoing,
      );
      expect(rows.single.spentAmount, 0);
      final preview = previewEntryBudgets(
        rows: rows,
        draft: expense(30000),
        policy: policy,
        today: DateTime(2026, 11, 17),
      ).single;
      expect(preview.remaining, rows.single.budgetAmount - 30000);
    },
  );

  test(
    'percentage and carry adjustments are included in previews and allocation moves',
    () async {
      await db.budgetDao.setMonthlyExpectedIncome('2026-10', 200000);
      final target = await budget('식비', 0, percentage: 25);
      await db.budgetDao.updateBudgetGroupAdjustment(target, -10000);
      final source = await budget('취미', 100000, cat: otherCategory);
      await db.budgetDao.moveBudgetAllocation(
        month: '2026-10',
        period: period,
        fromGroupId: source,
        toGroupId: target,
        amount: 20000,
        draft: expense(60000),
      );
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      expect(rows.firstWhere((r) => r.groupId == target).budgetAmount, 60000);
      expect(rows.firstWhere((r) => r.groupId == source).budgetAmount, 80000);
      expect(rows.fold<int>(0, (sum, r) => sum + r.budgetAmount), 140000);
      expect(
        await db.transactionsDao.listTransactionsByMonth('2026-11'),
        isEmpty,
      );
    },
  );

  test(
    'stale source, overlapping draft and invalid target cannot partially move budgets',
    () async {
      final target = await budget('식비', 10000);
      final source = await budget('생활비', 50000);
      Future<void> move(int amount, {int? destination}) =>
          db.budgetDao.moveBudgetAllocation(
            month: '2026-10',
            period: period,
            fromGroupId: source,
            toGroupId: destination ?? target,
            amount: amount,
            draft: expense(40000),
          );
      await expectLater(
        move(20000),
        throwsStateError,
      ); // source would exceed after draft
      await db.transactionsDao.saveTransaction(draft: expense(50000));
      await expectLater(move(1000), throwsStateError);
      await expectLater(move(1000, destination: source), throwsArgumentError);
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      expect(rows.map((r) => r.adjustment), [0, 0]);
    },
  );

  test(
    'a failure writing the target rolls back the source allocation',
    () async {
      final target = await budget('식비', 10000);
      final source = await budget('취미', 50000, cat: otherCategory);
      await db.customStatement('''
      CREATE TRIGGER fail_target BEFORE UPDATE ON budget_groups
      WHEN NEW.id = $target BEGIN SELECT RAISE(ABORT, 'write failure'); END
    ''');
      await expectLater(
        db.budgetDao.moveBudgetAllocation(
          month: '2026-10',
          period: period,
          fromGroupId: source,
          toGroupId: target,
          amount: 20000,
          draft: expense(30000),
        ),
        throwsA(isA<Exception>()),
      );
      final rows = await db.budgetDao.budgetGroupVsActual(
        '2026-10',
        period: period,
      );
      expect(rows.map((r) => r.adjustment), [0, 0]);
      expect(rows.firstWhere((r) => r.groupId == source).budgetAmount, 50000);
    },
  );

  test('live preview reloads when a budget or transaction is saved', () async {
    final target = await budget('식비', 100000);
    final stream = db.budgetDao.watchEntryBudgetRows('2026-10', period: period);
    final queue = <int>[];
    final sub = stream.listen(
      (rows) => queue.add(rows.single.budgetAmount - rows.single.spentAmount),
    );
    Future<void> waitFor(int value) async {
      for (var i = 0; i < 100 && (queue.isEmpty || queue.last != value); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(queue.last, value);
    }

    try {
      await waitFor(100000);
      await db.budgetDao.updateBudgetGroupAdjustment(target, 10000);
      await waitFor(110000);
      await db.transactionsDao.saveTransaction(draft: expense(20000));
      await waitFor(90000);
    } finally {
      await sub.cancel();
    }
  });
}
