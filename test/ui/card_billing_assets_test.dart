import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/accounts/accounts_screen.dart';
import 'package:my_little_budget/ui/desktop/accounts/account_detail_screen.dart';
import 'package:my_little_budget/ui/desktop/accounts/widgets/account_form_dialog.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_account_detail_screen.dart';
import 'package:my_little_budget/ui/mobile/mobile_widgets.dart';

void main() {
  final today = DateTime(2026, 11, 10);
  Future<({AppDatabase db, Account card})> seed({
    bool configured = true,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    final card = accounts.firstWhere((a) => a.kind == 'card');
    final bank = accounts.firstWhere((a) => a.kind == 'bank');
    await db.accountsDao.saveAccount(
      id: card.id,
      currentBalance: 0,
      asOf: today,
      draft: AccountDraft(
        name: card.name,
        kind: 'card',
        initialBalance: 0,
        color: card.color,
        excludeFromTotal: false,
        isInvestment: false,
        cardPaymentDay: configured ? 14 : null,
        cardClosingDay: configured ? 31 : null,
        cardPaymentAccountUuid: configured ? bank.uuid : null,
      ),
    );
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    for (final entry in [
      ('2026-10-31', 100000),
      ('2026-11-05', 30000),
      ('2026-11-20', 50000),
    ]) {
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: entry.$2,
          occurredOn: entry.$1,
          occurredTime: '12:00',
          accountId: card.id,
          categoryId: category.id,
        ),
      );
    }
    return (db: db, card: card);
  }

  Future<void> pump(
    WidgetTester tester,
    AppDatabase db,
    Widget body,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          statementTodayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(home: Scaffold(body: body)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} list and detail show both balances and card bill',
      (tester) async {
        final data = await seed();
        try {
          final size = mobile ? const Size(320, 900) : const Size(1100, 1000);
          await pump(
            tester,
            data.db,
            mobile ? const MobileAccountsScreen() : const AccountsScreen(),
            size,
          );
          expect(find.text('이번 결제 · 2026-11-16'), findsOneWidget);
          expect(find.text('이후 청구될 돈'), findsOneWidget);
          expect(find.text('연결 출금계좌'), findsOneWidget);
          expect(find.textContaining(formatKRW(30000)), findsWidgets);
          expect(find.textContaining(formatKRW(80000)), findsWidgets);
          expect(find.text(formatKRW(100000)), findsOneWidget);
          expect(find.textContaining(formatKRW(80000)), findsWidgets);
          expect(tester.takeException(), isNull);
          await pump(
            tester,
            data.db,
            mobile
                ? MobileAccountDetailScreen(accountId: data.card.id)
                : AccountDetailScreen(accountId: data.card.id),
            size,
          );
          expect(find.text('오늘까지 쓴 금액'), findsOneWidget);
          expect(find.text('이번 달 전체 지출액'), findsOneWidget);
          expect(find.text('현재 잔액 · 오늘까지'), findsNothing);
          expect(find.text('이번 결제 · 2026-11-16'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await close(tester, data.db);
        }
      },
    );
  }

  testWidgets(
    'desktop settings save linked bank and adjust today without consuming future spending',
    (tester) async {
      final data = await seed(configured: false);
      try {
        final account = (await data.db.accountsDao.getAccountBalance(
          data.card.id,
          asOf: today,
        ))!;
        await pump(
          tester,
          data.db,
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  AccountFormDialog.show(context, account: account),
              child: const Text('편집 열기'),
            ),
          ),
          const Size(900, 1200),
        );
        await tester.tap(find.text('편집 열기'));
        await tester.pumpAndSettle();
        for (final entry in [
          ('card-payment-day', '3일'),
          ('card-closing-day', '5일'),
          ('card-payment-account', '주거래 통장'),
        ]) {
          await tester.tap(find.byKey(ValueKey(entry.$1)));
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.$2).last);
          await tester.pumpAndSettle();
        }
        final balance = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '오늘까지 쓴 금액',
        );
        expect(tester.widget<TextField>(balance).controller!.text, '30,000');
        await tester.enterText(balance, '20000');
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        final saved = (await data.db.accountsDao.getAccountBalance(
          data.card.id,
          asOf: today,
        ))!;
        expect(saved.balance, -120000);
        expect(saved.projectedBalance, -170000);
        expect(saved.cardSpendingToDate, 20000);
        expect(saved.cardMonthSpending, 70000);
        expect(saved.cardPaymentDay, 3);
        expect(saved.cardClosingDay, 5);
        expect(saved.cardPaymentAccountName, '주거래 통장');
        expect(tester.takeException(), isNull);
      } finally {
        await close(tester, data.db);
      }
    },
  );

  testWidgets(
    'mobile edit starts from today balance and preserves card settings',
    (tester) async {
      final data = await seed();
      try {
        await pump(
          tester,
          data.db,
          const MobileAccountsScreen(),
          const Size(390, 1000),
        );
        final cardWidget = find
            .ancestor(of: find.text('신용카드'), matching: find.byType(MobileCard))
            .first;
        final menu = find.descendant(
          of: cardWidget,
          matching: find.byType(PopupMenuButton<String>),
        );
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('수정'));
        await tester.pumpAndSettle();
        final balance = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '오늘까지 쓴 금액',
        );
        await tester.ensureVisible(balance);
        expect(
          tester
              .widget<TextField>(balance)
              .controller!
              .text
              .replaceAll(',', ''),
          '30000',
        );
        await tester.tap(balance);
        await tester.pumpAndSettle();
        for (final label in ['C', '2', '00', '00', '=']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('저장'));
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        final saved = (await data.db.accountsDao.getAccountBalance(
          data.card.id,
          asOf: today,
        ))!;
        expect(saved.balance, -120000);
        expect(saved.projectedBalance, -170000);
        expect(saved.cardSpendingToDate, 20000);
        expect(saved.cardMonthSpending, 70000);
        expect(saved.cardBilling!.dueAmount, 100000);
        expect(saved.cardBilling!.laterAmount, 70000);
        expect(saved.cardPaymentDay, 14);
        expect(saved.cardPaymentAccountName, '주거래 통장');
        expect(tester.takeException(), isNull);
      } finally {
        await close(tester, data.db);
      }
    },
  );
}
