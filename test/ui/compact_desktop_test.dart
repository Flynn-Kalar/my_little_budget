import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/shell/sidebar_shell.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/filter_panel.dart';

void main() {
  for (final width in [500.0, 600.0]) {
    testWidgets(
      'Desktop $width keeps desktop pages and sidebar',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.accountsDao.saveAccount(
          draft: const AccountDraft(
            name: '긴 이름의 카드 계좌',
            kind: 'card',
            initialBalance: -123456789,
            cardLimit: 999999999,
            color: '#94a3b8',
            excludeFromTotal: true,
            isInvestment: false,
          ),
          currentBalance: -123456789,
        );
        final account = (await db.accountsDao.getActiveAccounts()).first;
        for (final type in ['income', 'expense']) {
          final category = (await db.categoriesDao.getActiveCategories(
            type,
          )).first;
          await db.transactionsDao.saveTransaction(
            draft: TransactionDraft(
              type: type,
              amount: 123456789,
              occurredOn: currentDateKey(),
              occurredTime: '12:30',
              accountId: account.id,
              categoryId: category.id,
              memo: '폭이 좁은 창에서도 확인할 수 있어야 하는 긴 거래 메모',
            ),
          );
        }
        await db.notesDao.saveNote(
          title: '좁은 창에서 확인하는 긴 메모 제목',
          content: '메모 본문',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const MyLittleBudgetApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SidebarShell), findsOneWidget);
        expect(find.byType(TransactionsScreen), findsOneWidget);
        await tester.tap(find.text('검색·필터'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'expanded filter');
        final search = find
            .descendant(
              of: find.byType(FilterPanel),
              matching: find.byType(TextField),
            )
            .first;
        await tester.enterText(search, '길게 입력한 검색어가 화면 밖으로 넘치지 않아야 합니다');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'long search');
        await tester.tap(find.byTooltip('필터 접기'));
        await tester.pumpAndSettle();
        final pageState = tester.state(find.byType(TransactionsScreen));
        final amountField = find.byKey(
          const ValueKey('desktop-transactions-inline-amount'),
        );
        await tester.enterText(amountField, '12345');
        for (final resizedWidth in [900.0, 1199.0, 1200.0, 1600.0, width]) {
          await tester.binding.setSurfaceSize(Size(resizedWidth, 1000));
          await tester.pumpAndSettle();
          expect(find.byType(SidebarShell), findsOneWidget);
          expect(
            tester.widget<TextField>(amountField).controller!.text,
            '12,345',
          );
          expect(
            tester.state(find.byType(TransactionsScreen)),
            same(pageState),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'resize $resizedWidth',
          );
        }
        final router = GoRouter.of(tester.element(find.byType(SidebarShell)));
        for (final route in [
          '/transactions',
          '/stats',
          '/accounts',
          '/notes',
          '/settings',
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(find.byType(NavigationBar), findsNothing, reason: route);
          expect(tester.takeException(), isNull, reason: route);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }),
    );
  }

  for (final width in [390.0, 600.0, 899.0]) {
    testWidgets(
      'Mobile $width retains bottom navigation',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
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
        final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
        for (final route in [
          '/transactions',
          '/stats',
          '/accounts',
          '/notes',
          '/settings',
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(SidebarShell), findsNothing);
          expect(find.byType(TransactionsScreen), findsNothing);
          expect(tester.takeException(), isNull, reason: route);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
