import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/core/date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('labels use actual start or end month without changing the range', () {
    const start = StatementPeriod(day: 30);
    final end = start.copyWith(labelByEnd: true);
    expect(start.displayMonth('2026-10'), '2026-10');
    expect(end.displayMonth('2026-10'), '2026-11');
    expect(end.range('2026-10'), start.range('2026-10'));
    expect(end.anchorForDisplay('2026-12', '2026-10'), '2026-11');
    expect(end.displayMonth('2026-12'), '2027-01');
    expect(
      const StatementPeriod(adjustment: 'previous').displayMonth('2026-01'),
      '2025-12',
    );
    expect(end.copyWith(day: 25).labelByEnd, isTrue);
    expect(end.copyWith(adjustment: 'next').labelByEnd, isTrue);
  });
  test('legacy settings default to start; end label persists', () async {
    SharedPreferences.setMockInitialValues({
      'transaction_statement_period': '30:previous',
    });
    final first = ProviderContainer();
    final old = await first.read(statementPeriodProvider.future);
    expect(old.labelByEnd, isFalse);
    expect(old.adjustment, 'previous');
    await first
        .read(statementPeriodProvider.notifier)
        .save(old.copyWith(labelByEnd: true));
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);
    final saved = await second.read(statementPeriodProvider.future);
    expect(saved.labelByEnd, isTrue);
    expect(saved.day, 30);
    expect(saved.adjustment, 'previous');
  });
  test(
    'transaction providers share boundaries and react to saved settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories())
          .firstWhere((c) => c.type == 'expense');
      for (final date in [
        '2026-10-24',
        '2026-10-25',
        '2026-11-24',
        '2026-11-25',
      ]) {
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: 100,
            occurredOn: date,
            occurredTime: '12:00',
            accountId: account.id,
            categoryId: category.id,
          ),
        );
      }
      container.read(selectedMonthProvider.notifier).state = '2026-10';
      await container.read(statementPeriodProvider.future);
      await container
          .read(statementPeriodProvider.notifier)
          .save(const StatementPeriod(day: 25));
      expect(
        (await container.read(
          transactionsListProvider.future,
        )).map((r) => r.occurredOn).toSet(),
        {'2026-10-25', '2026-11-24'},
      );
      expect(
        (await container.read(monthlySummaryProvider.future)).expense,
        200,
      );
      expect(
        (await container.read(
          transactionsCategoryBreakdownProvider.future,
        )).single.total,
        200,
      );
      expect(
        (await container.read(
          transactionsMonthlyTrendProvider.future,
        )).last.expense,
        200,
      );
      await container
          .read(statementPeriodProvider.notifier)
          .save(const StatementPeriod());
      expect(
        (await container.read(
          transactionsListProvider.future,
        )).map((r) => r.occurredOn).toSet(),
        {'2026-10-24', '2026-10-25'},
      );
      container.dispose();
      await db.close();
    },
  );
  test('default, chosen day, month end and leap year', () {
    expect(const StatementPeriod().range('2026-10'), (
      start: '2026-10-01',
      end: '2026-10-31',
    ));
    expect(const StatementPeriod(day: 25).range('2026-10'), (
      start: '2026-10-25',
      end: '2026-11-24',
    ));
    expect(const StatementPeriod(day: 31).range('2024-02'), (
      start: '2024-02-29',
      end: '2024-03-30',
    ));
    expect(const StatementPeriod(day: 0).range('2026-02'), (
      start: '2026-02-28',
      end: '2026-03-30',
    ));
  });
  test('holidays cross month and year without gaps or overlaps', () {
    expect(
      toDateKey(const StatementPeriod(adjustment: 'previous').start('2026-01')),
      '2025-12-31',
    );
    expect(
      toDateKey(const StatementPeriod(adjustment: 'next').start('2026-01')),
      '2026-01-02',
    );
    expect(
      toDateKey(
        const StatementPeriod(day: 25, adjustment: 'previous').start('2026-10'),
      ),
      '2026-10-23',
    );
    expect(
      toDateKey(
        const StatementPeriod(day: 25, adjustment: 'next').start('2026-10'),
      ),
      '2026-10-26',
    );
    for (final day in List.generate(32, (i) => i)) {
      for (final adjustment in ['same', 'previous', 'next']) {
        final policy = StatementPeriod(day: day, adjustment: adjustment);
        for (var m = 0; m < 24; m++) {
          final month = shiftMonth('2025-01', m);
          final range = policy.range(month);
          expect(range.start.compareTo(range.end), lessThanOrEqualTo(0));
          expect(
            toDateKey(parseDateKey(range.end).add(const Duration(days: 1))),
            policy.range(shiftMonth(month, 1)).start,
          );
        }
      }
    }
  });
  test('persists the complete policy across provider containers', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    expect((await first.read(statementPeriodProvider.future)).day, 1);
    await first
        .read(statementPeriodProvider.notifier)
        .save(const StatementPeriod(day: 0, adjustment: 'previous'));
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(statementPeriodProvider.future);
    expect(restored.day, 0);
    expect(restored.adjustment, 'previous');
  });
}
