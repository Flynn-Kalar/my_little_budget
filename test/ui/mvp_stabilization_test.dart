import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/settings/data_management_screen.dart';

void main() {
  Future<AppDatabase> pumpAppAt(WidgetTester tester, String route) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('my_little_budget'));
    GoRouter.of(context).go(route);
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('Budget MVP renders group modes and refreshes expected income', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedBudget(db);

    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('my_little_budget'))).go('/budget');
    await tester.pumpAndSettle();

    expect(find.text('Food Fixed'), findsOneWidget);
    expect(find.text('Needs Percent'), findsOneWidget);
    expect(find.text('Cash Flow'), findsOneWidget);
    expect(find.text(formatKRW(3000000)), findsWidgets);
    expect(find.text(formatKRW(600000)), findsWidgets);
    expect(find.text(formatKRW(1500000)), findsWidgets);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '3500000');
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await tester.pumpAndSettle();

    expect(find.text(formatKRW(3500000)), findsWidgets);
    expect(find.text(formatKRW(700000)), findsWidgets);
  });

  testWidgets(
    'Investments MVP renders rows, inline forms, precision, and PnL',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedInvestments(db);

      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MyLittleBudgetApp(),
        ),
      );
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.text('my_little_budget')),
      ).go('/investments');
      await tester.pumpAndSettle();

      expect(find.text('BUY'), findsWidgets);
      expect(find.text('SELL'), findsWidgets);
      expect(find.text('DIVIDEND'), findsWidgets);
      expect(find.text('0.3333'), findsOneWidget);
      expect(find.text('0.1111'), findsWidgets);
      expect(find.text('0.2222'), findsOneWidget);
      expect(find.text(formatKRW(15000)), findsWidgets);
      expect(find.text(formatKRW(500)), findsWidgets);

      final ticker = find.text('ABCD').first;
      await tester.ensureVisible(ticker);
      await tester.tap(ticker);
      await tester.pumpAndSettle();

      expect(find.textContaining('0.2222'), findsAtLeastNWidgets(2));
      expect(find.byIcon(Icons.north_east), findsWidgets);
      expect(find.byIcon(Icons.payments_outlined), findsWidgets);
    },
  );

  testWidgets('Settings MVP renders theme and backup surfaces', (tester) async {
    await pumpAppAt(tester, '/settings/theme');

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    GoRouter.of(
      tester.element(find.text('my_little_budget')),
    ).go('/settings/backup');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-backup-export-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-backup-import-button')),
      findsOneWidget,
    );
  });

  testWidgets('Settings backup import confirmation warns full replacement', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showImportConfirmationDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('백업 데이터 복원'), findsOneWidget);
    expect(
      find.text('현재 데이터를 모두 덮어쓰고 백업 데이터를 복원합니다. 되돌릴 수 없습니다.'),
      findsOneWidget,
    );
    expect(find.text('복원'), findsOneWidget);
  });
}

Future<void> _seedBudget(AppDatabase db) async {
  final month = currentMonthKey();
  final day = '$month-01';
  final accounts = await db.accountsDao.getActiveAccounts();
  final accountId = accounts.first.id;
  final categories = await db.categoriesDao.getActiveCategories('expense');

  await db.budgetDao.setMonthlyExpectedIncome(month, 3000000);
  await db.budgetDao.createBudgetGroup(
    name: 'Food Fixed',
    month: month,
    amount: 600000,
    categoryIds: [categories[0].id],
  );
  await db.budgetDao.createBudgetGroup(
    name: 'Needs Percent',
    month: month,
    amount: 0,
    percentage: 20,
    categoryIds: [categories[1].id],
  );
  await db.budgetDao.createBudgetGroup(
    name: 'Cash Flow',
    month: month,
    amount: 0,
    accountId: accountId,
  );

  await db.transactionsDao.saveTransaction(
    draft: TransactionDraft(
      type: 'income',
      amount: 1500000,
      occurredOn: day,
      occurredTime: '09:00',
      accountId: accountId,
      categoryId: (await db.categoriesDao.getActiveCategories(
        'income',
      )).first.id,
    ),
  );
  await db.transactionsDao.saveTransaction(
    draft: TransactionDraft(
      type: 'expense',
      amount: 100000,
      occurredOn: day,
      occurredTime: '10:00',
      accountId: accountId,
      categoryId: categories[0].id,
    ),
  );
}

Future<void> _seedInvestments(AppDatabase db) async {
  final month = currentMonthKey();
  final day = '$month-01';
  await db.accountsDao.saveAccount(
    draft: const AccountDraft(
      name: 'Invest Test',
      kind: 'bank',
      initialBalance: 0,
      color: '#64748b',
      excludeFromTotal: false,
      isInvestment: true,
    ),
    currentBalance: 0,
  );

  for (final draft in [
    const InvestmentDraft(
      side: 'buy',
      occurredOn: '',
      occurredTime: '09:00',
      ticker: 'ABCD',
      quantity: 0.3333,
      totalAmount: 30000,
    ),
    const InvestmentDraft(
      side: 'sell',
      occurredOn: '',
      occurredTime: '10:00',
      ticker: 'ABCD',
      quantity: 0.1111,
      totalAmount: 15000,
    ),
    const InvestmentDraft(
      side: 'dividend',
      occurredOn: '',
      occurredTime: '11:00',
      ticker: 'ABCD',
      quantity: 0,
      totalAmount: 500,
    ),
  ]) {
    await db.investmentsDao.saveInvestment(
      draft: InvestmentDraft(
        side: draft.side,
        occurredOn: day,
        occurredTime: draft.occurredTime,
        ticker: draft.ticker,
        quantity: draft.quantity,
        totalAmount: draft.totalAmount,
      ),
    );
  }
}
