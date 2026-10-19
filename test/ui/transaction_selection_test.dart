import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/transaction_list.dart';
import 'package:my_little_budget/ui/mobile/transactions/mobile_transactions_screen.dart';

void main() {
  late AppDatabase db;
  late List<int> ids;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    ids = [];
    for (var i = 0; i < 4; i++) {
      ids.add(
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: (i + 1) * 1000,
            occurredOn: '${currentMonthKey()}-01',
            occurredTime: '1$i:00',
            accountId: account.id,
            categoryId: category.id,
            memo: '선택 테스트 $i',
          ),
        ),
      );
    }
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester, {bool mobile = false}) async {
    await tester.binding.setSurfaceSize(
      mobile ? const Size(390, 844) : const Size(800, 800),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: mobile
                ? const MobileTransactionsScreen()
                : const TransactionList(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(int id, {bool mobile = false}) => find.byKey(
    ValueKey('${mobile ? 'mobile' : 'desktop'}-transaction-row-$id'),
  );
  Finder checkbox(int id, {bool mobile = false}) => find.byKey(
    ValueKey('${mobile ? 'mobile' : 'desktop'}-transaction-checkbox-$id'),
  );

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} selected delete confirms totals, supports cancel, and removes only selected rows',
      (tester) async {
        await open(tester, mobile: mobile);
        await tester.ensureVisible(row(ids[0], mobile: mobile));
        await tester.longPress(row(ids[0], mobile: mobile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(row(ids[1], mobile: mobile));
        await tester.tap(row(ids[1], mobile: mobile));
        await tester.pumpAndSettle();
        final delete = find.byKey(
          const ValueKey('transaction-selection-delete-button'),
        );
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(find.text('선택한 거래 삭제'), findsOneWidget);
        expect(find.textContaining('선택한 2건을 삭제할까요?'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('지출 ${formatKRW(3000)}'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(find.text('2건 선택'), findsOneWidget);
        expect(await db.transactionsDao.getTransactionById(ids[0]), isNotNull);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('transaction-selection-confirm-delete')),
        );
        await tester.pumpAndSettle();
        for (final id in ids.take(2)) {
          expect(await db.transactionsDao.getTransactionById(id), isNull);
          expect(row(id, mobile: mobile), findsNothing);
        }
        expect(await db.transactionsDao.getTransactionById(ids[2]), isNotNull);
        expect(await db.transactionsDao.getTransactionById(ids[3]), isNotNull);
        expect(
          find.byKey(const ValueKey('transaction-selection-toolbar')),
          findsNothing,
        );
        expect(find.byType(Checkbox), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'delete failure retains selection and shows an error without expanding editing',
    (tester) async {
      await open(tester);
      await tester.longPress(row(ids[0]));
      await tester.pumpAndSettle();
      await tester.tap(row(ids[1]));
      await tester.pumpAndSettle();
      await db.customStatement(
        '''CREATE TRIGGER fail_ui_bulk_delete BEFORE DELETE ON transactions
      WHEN OLD.id = ${ids[1]} BEGIN SELECT RAISE(ABORT, 'test failure'); END''',
      );
      await tester.tap(
        find.byKey(const ValueKey('transaction-selection-delete-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('transaction-selection-confirm-delete')),
      );
      await tester.pumpAndSettle();
      expect(find.text('삭제하지 못했습니다. 목록을 확인한 뒤 다시 시도해주세요.'), findsOneWidget);
      expect(find.text('2건 선택'), findsOneWidget);
      expect(await db.transactionsDao.getTransactionById(ids[0]), isNotNull);
      expect(await db.transactionsDao.getTransactionById(ids[1]), isNotNull);
      await tester.tap(find.text('선택 해제'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('transaction-selection-delete-button')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PC hides checkboxes until a mouse hold and supports Shift range',
    (tester) async {
      await open(tester);
      expect(find.byType(Checkbox), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(row(ids[0])),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Checkbox), findsNWidgets(4));
      expect(tester.widget<Checkbox>(checkbox(ids[0])).value, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(row(ids[2]));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('3건 선택'), findsOneWidget);
      for (final id in ids.take(3)) {
        expect(tester.widget<Checkbox>(checkbox(id)).value, isTrue);
      }
      expect(tester.widget<Checkbox>(checkbox(ids[3])).value, isFalse);

      await tester.tap(find.byTooltip('선택 모드 종료'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const ValueKey('transaction-selection-toolbar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'query select all stays within results and filter changes end selection',
    (tester) async {
      container.read(searchFilterProvider.notifier).state =
          const TransactionFilter(q: '테스트 1');
      await open(tester);
      await tester.longPress(row(ids[1]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('조회 결과 전체 선택 (1건)'));
      await tester.pumpAndSettle();
      expect(find.text('1건 선택'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      container.read(searchFilterProvider.notifier).state =
          const TransactionFilter();
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const ValueKey('transaction-selection-toolbar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inline category editing changes selected rows and retains selection after refresh',
    (tester) async {
      await open(tester);
      await tester.longPress(row(ids[0]));
      await tester.pumpAndSettle();
      await tester.tap(row(ids[1]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일괄 수정'));
      await tester.pumpAndSettle();
      final categories = await db.categoriesDao.getActiveCategories('expense');
      final target = categories[1];
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.name).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '2건에 적용'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('2건 선택'), findsOneWidget);
      for (final id in ids.take(2)) {
        expect(
          (await db.transactionsDao.getTransactionById(id))!.categoryId,
          target.id,
        );
        expect(tester.widget<Checkbox>(checkbox(id)).value, isTrue);
      }
      expect(
        (await db.transactionsDao.getTransactionById(ids[2]))!.categoryId,
        categories.first.id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile long press selects inline and taps toggle without opening edit sheets',
    (tester) async {
      await open(tester, mobile: true);
      expect(find.byType(Checkbox), findsNothing);
      await tester.ensureVisible(row(ids[0], mobile: true));
      await tester.longPress(row(ids[0], mobile: true));
      await tester.pumpAndSettle();
      await tester.ensureVisible(row(ids[1], mobile: true));
      await tester.tap(row(ids[1], mobile: true));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.widget<Checkbox>(checkbox(ids[0], mobile: true)).value,
        isTrue,
      );
      expect(
        tester.widget<Checkbox>(checkbox(ids[1], mobile: true)).value,
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('선택 모드 종료'));
      await tester.tap(find.byTooltip('선택 모드 종료'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact PC keeps list visible when inline editor is expanded',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(950, 680));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(row(ids[3]));
      await tester.longPress(row(ids[3]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일괄 수정'));
      await tester.pumpAndSettle();
      final list = find.byKey(
        const ValueKey('desktop-transactions-list-scroll'),
      );
      expect(tester.getSize(list).height, greaterThan(30));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('선택 모드 종료'));
      await tester.tap(find.byTooltip('선택 모드 종료'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
