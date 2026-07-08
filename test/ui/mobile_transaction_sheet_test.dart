import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/mobile/transactions/sheets/mobile_transaction_sheet.dart';

void main() {
  testWidgets('mobile transaction amount field saves arithmetic expressions', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accountId = (await db.accountsDao.getActiveAccounts()).first.id;
    final categoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 1,
        occurredOn: currentDateKey(),
        occurredTime: '12:00',
        accountId: accountId,
        categoryId: categoryId,
      ),
    );
    final row = (await db.transactionsDao.listTransactionsByMonth(
      currentMonthKey(),
    )).single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(body: MobileTransactionSheet(row: row)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const amountKey = ValueKey('mobile-transaction-amount-field');
    final amountField = find.byKey(amountKey);
    expect(amountField, findsOneWidget);
    expect(
      tester.widget<TextField>(amountField).keyboardType,
      TextInputType.text,
    );

    await tester.enterText(amountField, '1000+2000*3');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final updated = (await db.transactionsDao.listTransactionsByMonth(
      currentMonthKey(),
    )).single;
    expect(updated.amount, 7000);
  });
}
