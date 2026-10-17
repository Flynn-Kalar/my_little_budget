import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/transactions/transaction_csv.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/inline_entry.dart';
import 'package:my_little_budget/ui/mobile/mobile_widgets.dart';
import 'package:my_little_budget/ui/mobile/transactions/sheets/mobile_transaction_sheet.dart';
import 'package:my_little_budget/ui/shared/bulk_transaction_editor.dart';
import 'package:my_little_budget/ui/shared/transaction_csv_panel.dart';

void main() {
  late AppDatabase db;
  late int sourceId;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    sourceId = await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 5000,
        occurredOn: '2020-01-02',
        occurredTime: '12:00',
        accountId: account.id,
        categoryId: category.id,
        memo: '편의점',
      ),
      tagNames: ['점심'],
    );
  });
  tearDown(() => db.close());

  Widget host(Widget child) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets(
    'desktop memo selection fills metadata and preserves typed amount, date and time',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(const SingleChildScrollView(child: InlineEntry())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('desktop-transactions-inline-amount')),
        '12345',
      );
      await tester.enterText(
        find.byKey(const ValueKey('desktop-transactions-inline-date')),
        '2026-10-19',
      );
      await tester.enterText(
        find.byKey(const ValueKey('desktop-transactions-inline-time')),
        '15:45',
      );
      await tester.enterText(
        find.byKey(const ValueKey('desktop-transactions-memo-field')),
        '편의',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('편의점'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();
      final row = (await db.transactionsDao.listTransactionsByMonth(
        '2026-10',
      )).single;
      expect(row.amount, 12345);
      expect(row.occurredOn, '2026-10-19');
      expect(row.occurredTime, '15:45');
      expect(row.tags.single.name, '점심');
      expect(
        row.accountId,
        (await db.transactionsDao.getTransactionById(sourceId))!.accountId,
      );
    },
  );

  testWidgets(
    'mobile suggestion can fill an entry without replacing the amount',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => MobileTransactionSheet.show(context),
              child: const Text('입력 열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('입력 열기'));
      await tester.pumpAndSettle();
      tester
              .widget<MobileAmountField>(find.byType(MobileAmountField))
              .controller
              .text =
          '9900';
      final memo = find.byKey(const ValueKey('mobile-transaction-memo-field'));
      await tester.ensureVisible(memo);
      await tester.enterText(memo, '편의');
      await tester.pumpAndSettle();
      final suggestion = find.textContaining('편의점 ·');
      await tester.ensureVisible(suggestion);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      final save = find.widgetWithText(FilledButton, '저장');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final row = (await db.transactionsDao.listTransactionsByMonth(
        currentMonthKey(),
      )).single;
      expect(row.amount, 9900);
      expect(row.tags.single.name, '점심');
    },
  );

  testWidgets(
    'bulk editor fits mobile and applies tag changes to selected rows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final source = (await db.transactionsDao.getTransactionById(sourceId))!;
      final id = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: source.type,
          amount: 1000,
          occurredOn: currentDateKey(),
          occurredTime: '12:00',
          accountId: source.accountId,
          categoryId: source.categoryId,
        ),
      );
      await tester.pumpWidget(
        host(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showBulkTransactionEditor(context, ref),
              child: const Text('일괄 수정 열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('일괄 수정 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 선택 (1건)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('새 태그로 교체').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '공통, 정리');
      await tester.tap(find.widgetWithText(FilledButton, '1건에 적용'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        (await db.transactionsDao.getTransactionById(
          id,
        ))!.tags.map((t) => t.name).toSet(),
        {'공통', '정리'},
      );
      expect(
        (await db.transactionsDao.getTransactionById(
          sourceId,
        ))!.tags.single.name,
        '점심',
      );
    },
  );

  testWidgets(
    'CSV preview at mobile size shows duplicate summary and allows import',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rows = parseTransactionCsv(
        exportTransactionCsv(await db.backupDao.exportBackup()),
      );
      rows[1][0] = currentDateKey();
      rows.add(List.of(rows[1]));
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTransactionCsvImport(context, rows),
              child: const Text('CSV 열기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('CSV 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('검증 및 미리보기'));
      await tester.pumpAndSettle();
      expect(find.text('가져올 거래 1건 · 중복 1건 · 오류 0건'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, '1건 가져오기'));
      await tester.pumpAndSettle();
      expect(
        (await db.transactionsDao.listTransactionsByMonth(
          currentMonthKey(),
        )).length,
        1,
      );
    },
  );
}
