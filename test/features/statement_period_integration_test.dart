import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/budget/daily_allowance.dart';
import 'package:my_little_budget/features/budget/providers.dart';
import 'package:my_little_budget/features/home/providers.dart';
import 'package:my_little_budget/features/investments/providers.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/features/recurring/validation.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  test(
    'manual months survive policy changes while untouched months follow the current period',
    () async {
      SharedPreferences.setMockInitialValues({});
      var date = DateTime(2026, 11, 1);
      final scope = ProviderContainer(
        overrides: [statementTodayProvider.overrideWith((ref) => date)],
      );
      addTearDown(scope.dispose);
      await scope.read(statementPeriodProvider.future);
      final months = [
        selectedMonthProvider,
        homeMonthProvider,
        budgetMonthProvider,
        statsMonthProvider,
        investmentMonthProvider,
      ];
      for (final provider in months) {
        expect(scope.read(provider), '2026-11');
      }
      await scope
          .read(statementPeriodProvider.notifier)
          .save(const StatementPeriod(day: 25));
      for (final provider in months) {
        expect(scope.read(provider), '2026-10');
        scope.read(provider.notifier).state = '2025-12';
      }
      await scope
          .read(statementPeriodProvider.notifier)
          .save(const StatementPeriod());
      date = DateTime(2027, 1, 1);
      scope.invalidate(statementTodayProvider);
      for (final provider in months) {
        expect(scope.read(provider), '2025-12');
      }
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late DateTime today;
  setUp(() async {
    today = DateTime(2026, 10, 30);
    SharedPreferences.setMockInitialValues({
      'transaction_statement_period': '30:same:end',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        statementTodayProvider.overrideWith((ref) => today),
      ],
    );
    await container.read(statementPeriodProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'all monthly totals use the same period and labels preserve budgets',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      for (final (date, amount) in [
        ('2026-10-29', 1000),
        ('2026-10-30', 100),
        ('2026-11-29', 200),
        ('2026-11-30', 2000),
      ]) {
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: amount,
            occurredOn: date,
            occurredTime: '12:00',
            accountId: account.id,
            categoryId: category.id,
          ),
          tagNames: ['테스트'],
        );
      }
      await db.budgetDao.createBudgetGroup(
        name: '예산',
        month: '2026-10',
        amount: 1000,
        categoryIds: [category.id],
        carryForward: true,
      );
      expect(container.read(selectedMonthProvider), '2026-10');
      expect(container.read(homeMonthProvider), '2026-10');
      expect(container.read(budgetMonthProvider), '2026-10');
      expect(container.read(statsMonthProvider), '2026-10');
      expect(
        (await container.read(monthlySummaryProvider.future)).expense,
        300,
      );
      expect(
        (await container.read(budgetRowsProvider.future)).single.spentAmount,
        300,
      );
      container.listen(homeOverviewProvider, (_, _) {});
      final home = await container.read(homeOverviewProvider.future);
      expect(home.summary.expense, 300);
      expect(home.spent, 300);
      final categoryRows = await container.read(
        statsExpenseBreakdownProvider.future,
      );
      expect(categoryRows.single.total, 300);
      container.read(statsSelectedCategoryProvider.notifier).state =
          categoryRows.single;
      final tags = await container.read(statsTagBreakdownProvider.future);
      expect(tags.single.total, 300);
      container.read(statsSelectedTagProvider.notifier).state = tags.single;
      expect(
        (await container.read(
          statsTagTransactionsProvider.future,
        )).map((r) => r.occurredOn).toSet(),
        {'2026-10-30', '2026-11-29'},
      );
      final trend = await container.read(statsMonthlyTrendProvider.future);
      expect(trend.last.month, '2026-11');
      expect(trend.last.expense, 300);
      await db.budgetDao.copyBudgetGroupsWithCarryforward(
        '2026-10',
        '2026-11',
        sourcePeriod: const StatementPeriod(day: 30).range('2026-10'),
      );
      expect(
        (await db.budgetDao.budgetGroupVsActual('2026-11')).single.budgetAmount,
        1700,
      );
      await container
          .read(statementPeriodProvider.notifier)
          .save(const StatementPeriod(day: 30));
      expect(
        (await container.read(statsMonthlyTrendProvider.future)).last.month,
        '2026-10',
      );
      expect(
        (await container.read(budgetRowsProvider.future)).single.spentAmount,
        300,
      );
    },
  );

  test(
    'recurring batches keep configured dates and advance only through period end',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      for (final day in [5, 30]) {
        final result = validateRecurring(
          type: 'expense',
          name: '반복 $day',
          amount: 100,
          frequency: 'monthly',
          dayOfMonth: day,
          occurredTime: '09:00',
          startDate: '2026-10-30',
          accountId: account.id,
          categoryId: category.id,
        );
        await db.recurringDao.saveRecurring(draft: result.value!);
      }
      expect(await container.read(recurringBackfillProvider.future), 2);
      final first = await db.transactionsDao.listTransactionsByMonth(
        '2026-10',
        period: const StatementPeriod(day: 30).range('2026-10'),
      );
      expect(first.map((r) => r.occurredOn).toSet(), {
        '2026-10-30',
        '2026-11-05',
      });
      today = DateTime(2026, 11, 1);
      container.invalidate(statementTodayProvider);
      container.invalidate(recurringBackfillProvider);
      expect(await container.read(recurringBackfillProvider.future), 0);
      expect(container.read(currentStatementMonthProvider), '2026-10');
      today = DateTime(2026, 11, 30);
      container.invalidate(statementTodayProvider);
      container.invalidate(recurringBackfillProvider);
      expect(await container.read(recurringBackfillProvider.future), 2);
      expect(container.read(currentStatementMonthProvider), '2026-11');
      final second = await db.transactionsDao.listTransactionsByMonth(
        '2026-11',
        period: const StatementPeriod(day: 30).range('2026-11'),
      );
      expect(second.map((r) => r.occurredOn).toSet(), {
        '2026-11-30',
        '2026-12-05',
      });
      container.invalidate(recurringBackfillProvider);
      expect(await container.read(recurringBackfillProvider.future), 0);
    },
  );

  test(
    'annual statistics and investments include dates from the labelled year',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      for (final (date, amount) in [
        ('2025-12-29', 1000),
        ('2025-12-30', 100),
        ('2026-12-29', 200),
        ('2026-12-30', 2000),
      ]) {
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: amount,
            occurredOn: date,
            occurredTime: '12:00',
            accountId: account.id,
            categoryId: category.id,
          ),
        );
        await db.investmentsDao.saveInvestment(
          draft: validateInvestment(
            side: 'buy',
            ticker: 'TEST',
            occurredOn: date,
            occurredTime: '12:00',
            quantity: 1,
            totalAmount: amount,
          ).value!,
        );
      }
      container.read(statsYearProvider.notifier).state = 2026;
      final rows = await container.read(yearlyMonthlyTrendProvider.future);
      expect(rows.first.expense, 100);
      expect(rows.last.expense, 200);
      expect(rows.fold<int>(0, (sum, row) => sum + row.expense), 300);
      expect(
        (await container.read(
          yearlyExpenseByCategoryProvider.future,
        )).single.total,
        300,
      );
      expect(await container.read(availableStatsYearsProvider.future), [
        2025,
        2026,
        2027,
      ]);
      expect(
        (await container.read(
          investmentYearlySummaryProvider(2026).future,
        )).buy,
        300,
      );
      expect(
        (await container.read(
          investmentYearlyRowsProvider(2026).future,
        )).length,
        2,
      );
      container.read(investmentMonthProvider.notifier).state = '2025-12';
      expect(
        (await container.read(investmentMonthlySummaryProvider.future)).buy,
        100,
      );
      expect(
        (await container.read(investmentRowsProvider.future)).single.occurredOn,
        '2025-12-30',
      );
    },
  );

  test('date lookup and daily allowance follow adjusted boundaries', () {
    for (final day in [0, 1, 25, 30, 31]) {
      for (final adjustment in ['same', 'previous', 'next']) {
        final policy = StatementPeriod(day: day, adjustment: adjustment);
        for (var i = 0; i < 24; i++) {
          final anchor = shiftMonth('2025-01', i);
          final range = policy.range(anchor);
          expect(policy.anchorForDate(parseDateKey(range.start)), anchor);
          expect(policy.anchorForDate(parseDateKey(range.end)), anchor);
        }
      }
    }
    final allowance = dailyAllowance(
      month: '2026-10',
      budget: 3000,
      spent: 100,
      now: DateTime(2026, 11, 1),
      period: const StatementPeriod(day: 30).range('2026-10'),
    )!;
    expect(allowance.days, 29);
    expect(allowance.daily, 100);
  });
}
