import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/settings/statement_period.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/shared/transaction_budget_preview.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/inline_entry.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/transaction_edit_dialog.dart';
import 'package:my_little_budget/ui/mobile/transactions/sheets/mobile_transaction_sheet.dart';

void main() {
  late AppDatabase db;
  late int account;
  late int category;
  late int otherCategory;
  late int group;
  late int original;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'transaction_statement_period': '25:same:end',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    account = (await db.accountsDao.getActiveAccounts()).first.id;
    final cats = await db.categoriesDao.getActiveCategories('expense');
    category = cats[0].id;
    otherCategory = cats[1].id;
    group = await db.budgetDao.createBudgetGroup(
      name: '식비 예산',
      month: '2026-10',
      amount: 100000,
      categoryIds: [category],
    );
    original = await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 20000,
        occurredOn: '2026-11-17',
        occurredTime: '12:00',
        accountId: account,
        categoryId: category,
        memo: '점심',
      ),
      tagNames: ['식사'],
    );
    final tag = (await db.tagsDao.getTags()).single;
    await db.tagsDao.updateTag(
      tag.id,
      tag.name,
      tag.color,
      categoryIds: [category],
    );
    await db.tagsDao.createTag('교통', '#64748b', categoryIds: [otherCategory]);
    await db.tagsDao.createTag('미분류', '#64748b');
  });
  tearDown(() => db.close());

  Widget host(Widget child, {double bottomInset = 0}) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      statementTodayProvider.overrideWithValue(DateTime(2026, 11, 17)),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(viewInsets: EdgeInsets.only(bottom: bottomInset)),
        child: child!,
      ),
      home: Scaffold(resizeToAvoidBottomInset: false, body: child),
    ),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'live amount expression, empty/error states, date changes and budget move preserve draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final amount = TextEditingController(text: '60000');
      addTearDown(amount.dispose);
      var date = DateTime(2026, 11, 17);
      late StateSetter rebuild;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return TransactionBudgetPreview(
                amountController: amount,
                type: 'expense',
                date: date,
                accountId: account,
                categoryId: category,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 예산 · ₩20,000 남음'), findsOneWidget);
      expect(find.text('하루 ₩2,500 사용 가능 · 8일 기준'), findsOneWidget);
      amount.text = '60,000+30,000';
      await tester.pumpAndSettle();
      expect(find.text('식비 예산 · ₩10,000 초과'), findsOneWidget);
      amount.text = '60,000+';
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('entry-budget-$group')), findsNothing);
      amount.text = '90000';
      await tester.pumpAndSettle();
      await db.budgetDao.createBudgetGroup(
        name: '취미 예산',
        month: '2026-10',
        amount: 50000,
        categoryIds: [otherCategory],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다른 예산에서 가져오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entry-budget-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취미 예산 · ₩50,000').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '이동'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('식비 예산 · ₩0 남음'), findsOneWidget);
      expect(amount.text, '90000');
      expect(
        (await db.transactionsDao.getTransactionById(original))!.amount,
        20000,
      );
      rebuild(() => date = DateTime(2026, 11, 25));
      await tester.pumpAndSettle();
      expect(find.text('이 자산·카테고리에 연결된 예산이 없습니다.'), findsOneWidget);
      expect(find.byKey(ValueKey('entry-budget-$group')), findsNothing);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    },
  );

  testWidgets('mobile compact form, keyboard, calculator preview and save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final row = (await db.transactionsDao.getTransactionById(original))!;
    await tester.pumpWidget(host(MobileTransactionSheet(row: row)));
    await tester.pumpAndSettle();
    expect(find.text('식비 예산 · ₩80,000 남음'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '#식사'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '#교통'), findsNothing);
    expect(find.byIcon(Icons.calendar_today), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('mobile-transaction-memo-field')))
          .bottom,
      lessThan(844),
    );
    expect(
      tester.getRect(find.widgetWithText(FilledButton, '저장')).bottom,
      lessThan(844),
    );
    await tester.tap(
      find.byKey(const ValueKey('mobile-transaction-amount-field')),
    );
    await tester.pumpAndSettle();
    for (final key in ['C', '6', '0', '00', '0']) {
      await tester.tap(find.byKey(ValueKey('mobile-transaction-keypad-$key')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('식비 예산 · ₩40,000 남음'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('mobile-transaction-keypad-=')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      host(MobileTransactionSheet(row: row), bottomInset: 300),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.widgetWithText(FilledButton, '저장')).bottom,
      lessThanOrEqualTo(544),
    );
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(
      (await db.transactionsDao.getTransactionById(original))!.amount,
      60000,
    );
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });

  testWidgets(
    'desktop edit excludes original and duplicate reserves additional expense',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final row = (await db.transactionsDao.getTransactionById(original))!;
      await tester.pumpWidget(host(TransactionEditDialog(row: row)));
      await tester.pumpAndSettle();
      expect(find.text('식비 예산 · ₩80,000 남음'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#식사'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, '#교통'), findsNothing);
      await tester.pumpWidget(
        host(
          TransactionEditDialog(
            key: const ValueKey('copy'),
            row: row,
            duplicate: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 예산 · ₩60,000 남음'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await dispose(tester);
    },
  );

  testWidgets(
    '360px mobile keeps save visible with many tags and keyboard; calculator fits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (var i = 0; i < 20; i++) {
        await db.tagsDao.createTag(
          '식사 태그 $i',
          '#64748b',
          categoryIds: [category],
        );
      }
      final row = (await db.transactionsDao.getTransactionById(original))!;
      await tester.pumpWidget(
        host(MobileTransactionSheet(row: row), bottomInset: 260),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.widgetWithText(FilledButton, '저장')).bottom,
        lessThanOrEqualTo(380),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(host(MobileTransactionSheet(row: row)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('mobile-transaction-amount-field')),
      );
      await tester.pumpAndSettle();
      expect(find.text('식비 예산 · ₩80,000 남음'), findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('mobile-transaction-keypad-=')))
            .bottom,
        lessThan(640),
      );
      expect(tester.takeException(), isNull);
      await dispose(tester);
    },
  );

  testWidgets('PC inline draft changes date and amount without saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      host(const SingleChildScrollView(child: InlineEntry())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('desktop-transactions-inline-amount')),
      '60000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('desktop-transactions-inline-date')),
      '2026-11-17',
    );
    await tester.enterText(
      find.byKey(const ValueKey('desktop-transactions-memo-field')),
      '점심',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('점심').last);
    await tester.pumpAndSettle();
    expect(find.text('식비 예산 · ₩20,000 남음'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('desktop-transactions-inline-amount')),
      '120000',
    );
    await tester.pumpAndSettle();
    expect(find.text('식비 예산 · ₩40,000 초과'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('desktop-transactions-inline-date')),
      '2026-11-25',
    );
    await tester.pumpAndSettle();
    expect(find.text('이 자산·카테고리에 연결된 예산이 없습니다.'), findsOneWidget);
    expect(
      (await db.transactionsDao.listTransactionsByMonth('2026-11')).length,
      1,
    );
    expect(tester.takeException(), isNull);
    await dispose(tester);
  });
}
