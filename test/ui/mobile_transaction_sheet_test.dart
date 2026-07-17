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
  testWidgets('시스템 내비게이션 영역 위에 저장 버튼을 배치한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            const systemNavigation = EdgeInsets.only(bottom: 48);
            return MediaQuery(
              data: mediaQuery.copyWith(
                padding: systemNavigation,
                viewPadding: systemNavigation,
              ),
              child: child!,
            );
          },
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => MobileTransactionSheet.show(context),
                  child: const Text('거래 추가 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('거래 추가 열기'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '저장');
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(844 - 48));
  });

  testWidgets('mobile amount field opens calculator page and returns result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    final textField = tester.widget<TextField>(amountField);
    expect(textField.readOnly, isTrue);
    expect(textField.keyboardType, TextInputType.none);
    expect(
      find.byKey(const ValueKey('mobile-transaction-amount-keypad')),
      findsNothing,
    );

    await tester.tap(amountField);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-transaction-amount-calculator-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-transaction-amount-keypad')),
      findsOneWidget,
    );

    for (final label in [
      'C',
      'backspace',
      '()',
      '÷',
      '×',
      '-',
      '+',
      '00',
      '=',
    ]) {
      expect(
        find.byKey(ValueKey('mobile-transaction-keypad-$label')),
        findsOneWidget,
      );
    }

    for (final label in ['C', '1', '0', '00', '+', '2', '0', '00', '×', '3']) {
      await tester.tap(
        find.byKey(ValueKey('mobile-transaction-keypad-$label')),
      );
      await tester.pump();
    }
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('mobile-transaction-calculator-display')),
          )
          .data,
      '1000+2000×3',
    );

    await tester.tap(find.byKey(const ValueKey('mobile-transaction-keypad-=')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-transaction-amount-calculator-page')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mobile-transaction-amount-keypad')),
      findsNothing,
    );
    final returnedAmountField = find.byKey(amountKey);
    expect(
      tester.widget<TextField>(returnedAmountField).controller?.text,
      '7000',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('mobile-transaction-memo-field')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    final updated = (await db.transactionsDao.listTransactionsByMonth(
      currentMonthKey(),
    )).single;
    expect(updated.amount, 7000);
  });
}
