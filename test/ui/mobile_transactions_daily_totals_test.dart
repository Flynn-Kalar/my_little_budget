import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/transactions/providers.dart';

void main() {
  testWidgets('mobile transaction date headers show visible daily totals', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accounts = await db.accountsDao.getActiveAccounts();
    final accountId = accounts.first.id;
    final transferToAccountId = accounts[1].id;
    final incomeCategoryId = (await db.categoriesDao.getActiveCategories(
      'income',
    )).first.id;
    final expenseCategoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;

    final firstDate = currentDateKey();
    final now = DateTime.now();
    final secondDate = toDateKey(
      DateTime(now.year, now.month, now.day == 1 ? 2 : now.day - 1),
    );

    Future<void> save({
      required String type,
      required int amount,
      required String date,
      int? accountId,
      int? categoryId,
      int? fromAccountId,
      int? toAccountId,
      String memo = 'daily-total-test',
    }) {
      return db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: type,
          amount: amount,
          occurredOn: date,
          occurredTime: '12:00',
          accountId: accountId,
          categoryId: categoryId,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          memo: memo,
        ),
      );
    }

    await save(
      type: 'income',
      amount: 1000,
      date: firstDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'income',
      amount: 2000,
      date: firstDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'expense',
      amount: 300,
      date: firstDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );
    await save(
      type: 'expense',
      amount: 700,
      date: firstDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );
    await save(
      type: 'transfer',
      amount: 9999,
      date: firstDate,
      fromAccountId: accountId,
      toAccountId: transferToAccountId,
    );
    await save(
      type: 'income',
      amount: 5000,
      date: secondDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'expense',
      amount: 4000,
      date: secondDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_dailyIncome(firstDate, 3000), findsOneWidget);
    expect(_dailyExpense(firstDate, 1000), findsOneWidget);
    expect(_dailyTransfer(firstDate, 1, 9999), findsOneWidget);
    expect(_dailyIncome(secondDate, 5000), findsOneWidget);
    expect(_dailyExpense(secondDate, 4000), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavigationBar)),
    );
    container.read(typeFilterProvider.notifier).state = 'expense';
    await tester.pumpAndSettle();

    expect(_dailyIncome(firstDate, 0), findsOneWidget);
    expect(_dailyExpense(firstDate, 1000), findsOneWidget);
    expect(_dailyIncome(secondDate, 0), findsOneWidget);
    expect(_dailyExpense(secondDate, 4000), findsOneWidget);
  });
}

Finder _dailyIncome(String date, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('mobile-transactions-date-income-$date')),
    matching: find.text('수입 ${formatKRW(amount)}'),
  );
}

Finder _dailyExpense(String date, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('mobile-transactions-date-expense-$date')),
    matching: find.text('지출 ${formatKRW(amount)}'),
  );
}

Finder _dailyTransfer(String date, int count, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('mobile-transactions-date-transfer-$date')),
    matching: find.text('이체 $count건 · ${formatKRW(amount)}'),
  );
}
