import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/month_nav.dart';

void main() {
  for (final width in [1000.0, 1400.0]) {
    testWidgets(
      'PC $width: scroll folds only summary and preserves draft/selection',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
        });
        final account = (await db.accountsDao.getActiveAccounts()).first;
        final category = (await db.categoriesDao.getActiveCategories(
          'expense',
        )).first;
        for (var i = 0; i < 35; i++) {
          await db.transactionsDao.saveTransaction(
            draft: TransactionDraft(
              type: 'expense',
              amount: 1000 + i,
              occurredOn: '${currentMonthKey()}-01',
              occurredTime: '12:00',
              accountId: account.id,
              categoryId: category.id,
              memo: '거래 $i',
            ),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const MaterialApp(
              home: Scaffold(body: TransactionsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final summary = find.byKey(
          const ValueKey('desktop-transactions-summary-bar'),
        );
        final list = find.byKey(
          const ValueKey('desktop-transactions-list-scroll'),
        );
        final memo = find.byKey(
          const ValueKey('desktop-transactions-memo-field'),
        );
        await tester.enterText(memo, '작성 중인 내용');
        final firstRow = find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('desktop-transaction-row-');
        });
        await tester.longPress(firstRow.first);
        await tester.pumpAndSettle();
        expect(find.text('1건 선택'), findsOneWidget);
        final originalListHeight = tester.getSize(list).height;
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;

        // Programmatic movement/layout changes must not fold the header.
        position.jumpTo(100);
        await tester.pumpAndSettle();
        expect(summary, findsOneWidget);

        // Actual mouse-wheel scrolling folds just the amount cards.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(list),
            scrollDelta: const Offset(0, 150),
          ),
        );
        await tester.pumpAndSettle();
        expect(summary, findsNothing);
        expect(tester.getSize(list).height, greaterThan(originalListHeight));
        expect(find.byType(MonthNav), findsOneWidget);
        expect(find.text('거래 내역'), findsOneWidget);
        expect(find.text('검색·필터'), findsOneWidget);
        expect(find.text('1건 선택'), findsOneWidget);
        expect(tester.widget<TextField>(memo).controller!.text, '작성 중인 내용');

        // Reverse wheel scrolling restores the cards before reaching the top.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(list),
            scrollDelta: const Offset(0, -50),
          ),
        );
        await tester.pumpAndSettle();
        expect(summary, findsOneWidget);
        expect(position.pixels, greaterThan(0));
        expect(find.text('1건 선택'), findsOneWidget);

        // Drag gestures support the same behavior, without losing form state.
        await tester.drag(list, const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(summary, findsNothing);
        await tester.drag(list, const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(summary, findsOneWidget);
        expect(tester.widget<TextField>(memo).controller!.text, '작성 중인 내용');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
