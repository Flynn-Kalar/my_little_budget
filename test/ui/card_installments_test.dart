import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/presets/validation.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/form_fields.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/inline_entry.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/transaction_edit_dialog.dart';
import 'package:my_little_budget/ui/mobile/transactions/sheets/mobile_transaction_sheet.dart';
import 'package:my_little_budget/ui/shared/account_financial_summary.dart';
import 'package:my_little_budget/ui/shared/installment_field.dart';

void main() {
  late AppDatabase db;
  late Account card;
  late Account bank;
  late Category category;
  final today = DateTime(2026, 11, 10);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    card = accounts.firstWhere((a) => a.kind == 'card');
    bank = accounts.firstWhere((a) => a.kind == 'bank');
    category = (await db.categoriesDao.getActiveCategories('expense')).first;
    await db.accountsDao.saveAccount(
      id: card.id,
      currentBalance: 0,
      draft: AccountDraft(
        name: card.name,
        kind: 'card',
        initialBalance: 0,
        color: card.color,
        excludeFromTotal: false,
        isInvestment: false,
        cardPaymentDay: 14,
        cardClosingDay: 31,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget body, bool mobile) async {
    await tester.binding.setSurfaceSize(
      mobile ? const Size(390, 950) : const Size(1100, 950),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

  Future<void> chooseAccount(
    WidgetTester tester,
    bool mobile,
    Account account,
  ) async {
    if (mobile) {
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(account.name).last);
    } else {
      final field = find.descendant(
        of: find.byType(AccountDropdown).first,
        matching: find.byType(TextField),
      );
      await tester.enterText(field, account.name);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
    }
    await tester.pumpAndSettle();
  }

  Future<void> chooseMonths(
    WidgetTester tester,
    int current,
    int months,
  ) async {
    final field = find.byKey(ValueKey('installment-months-$current'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('$months개월 할부').last);
    await tester.pumpAndSettle();
  }

  Future<int> purchase() => db.transactionsDao.saveTransaction(
    draft: TransactionDraft(
      type: 'expense',
      amount: 90000,
      occurredOn: '2026-10-31',
      occurredTime: '12:00',
      accountId: card.id,
      categoryId: category.id,
      installmentMonths: 3,
      memo: '노트북',
    ),
  );

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} creates installment purchase from preset',
      (tester) async {
        final preset = TransactionPresetDraft(
          name: '노트북 할부',
          type: 'expense',
          amount: 90000,
          accountId: card.id,
          categoryId: category.id,
          installmentMonths: 3,
        );
        if (mobile) {
          await db.transactionPresetsDao.savePreset(draft: preset);
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => MobileTransactionSheet.show(context),
                child: const Text('열기'),
              ),
            ),
            true,
          );
          await tester.tap(find.text('열기'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('mobile-transaction-preset-button')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('노트북 할부'));
          await tester.pumpAndSettle();
        } else {
          await pump(
            tester,
            const SingleChildScrollView(child: InlineEntry()),
            false,
          );
          await pump(
            tester,
            SingleChildScrollView(
              child: InlineEntry(preset: preset, presetRevision: 1),
            ),
            false,
          );
        }
        expect(
          find.byKey(const ValueKey('installment-months-3')),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, mobile ? '저장' : '추가'),
        );
        await tester.pumpAndSettle();
        final saved = (await db.select(db.transactions).get()).single;
        expect(saved.amount, 90000);
        expect(saved.installmentMonths, 3);
        if (!mobile) {
          expect(
            find.byKey(const ValueKey('installment-months-1')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} enables installments only for card expenses and clears on change',
      (tester) async {
        await pump(
          tester,
          mobile
              ? const MobileTransactionSheet()
              : const SingleChildScrollView(child: InlineEntry()),
          mobile,
        );
        expect(find.byType(InstallmentField), findsNothing);
        await chooseAccount(tester, mobile, bank);
        expect(find.byType(InstallmentField), findsNothing);
        await chooseAccount(tester, mobile, card);
        expect(
          find.byKey(const ValueKey('installment-months-1')),
          findsOneWidget,
        );
        await chooseMonths(tester, 1, 3);
        await chooseAccount(tester, mobile, bank);
        expect(find.byType(InstallmentField), findsNothing);
        await chooseAccount(tester, mobile, card);
        expect(
          find.byKey(const ValueKey('installment-months-1')),
          findsOneWidget,
        );
        await chooseMonths(tester, 1, 3);
        await tester.ensureVisible(find.text('수입').first);
        await tester.tap(find.text('수입').first);
        await tester.pumpAndSettle();
        expect(find.byType(InstallmentField), findsNothing);
        await tester.tap(find.text('지출').first);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('installment-months-1')),
          findsOneWidget,
        );
        await tester.tap(find.text('이체').first);
        await tester.pumpAndSettle();
        expect(find.byType(InstallmentField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final duplicate in [false, true]) {
      testWidgets(
        '${mobile ? 'mobile' : 'desktop'} ${duplicate ? 'copy' : 'edit'} saves selected installments',
        (tester) async {
          final id = await purchase();
          final row = (await db.transactionsDao.getTransactionById(id))!;
          await pump(
            tester,
            Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  if (mobile) {
                    if (duplicate) {
                      MobileTransactionSheet.showDuplicate(context, row);
                    } else {
                      MobileTransactionSheet.show(context, row: row);
                    }
                  } else {
                    if (duplicate) {
                      TransactionEditDialog.showDuplicate(context, row);
                    } else {
                      TransactionEditDialog.show(context, row);
                    }
                  }
                },
                child: const Text('열기'),
              ),
            ),
            mobile,
          );
          await tester.tap(find.text('열기'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('installment-months-3')),
            findsOneWidget,
          );
          await chooseMonths(tester, 3, 6);
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              !mobile && duplicate ? '추가' : '저장',
            ),
          );
          await tester.pumpAndSettle();
          final transactions = await db.select(db.transactions).get();
          expect(transactions, hasLength(duplicate ? 2 : 1));
          if (duplicate) {
            expect(
              transactions.firstWhere((t) => t.id == id).installmentMonths,
              3,
            );
          }
          expect(transactions.last.installmentMonths, 6);
          expect(transactions.last.amount, 90000);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'narrow card summary expands current round and all future amounts without overflow',
    (tester) async {
      await purchase();
      final balance = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      await tester.binding.setSurfaceSize(const Size(320, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountFinancialSummary(account: balance),
              ),
            ),
          ),
        ),
      );
      expect(find.text('할부 1건'), findsOneWidget);
      await tester.tap(find.text('할부 1건'));
      await tester.pumpAndSettle();
      expect(find.text('이번 청구 1/3회차'), findsOneWidget);
      expect(find.text('2026-12-14 · 2/3회차'), findsOneWidget);
      expect(find.text('2027-01-14 · 3/3회차'), findsOneWidget);
      expect(find.text('이후 2회 · 잔여 원금'), findsOneWidget);
      expect(find.textContaining('상환·환급 차감 전'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
