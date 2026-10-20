import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/router/app_router.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';
import 'package:my_little_budget/ui/mobile/transactions/mobile_transactions_screen.dart';
import 'package:my_little_budget/ui/desktop/page_back_button.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    for (var i = 0; i < 30; i++) {
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 100 + i,
          occurredOn: '2024-02-01',
          occurredTime: '12:00',
          accountId: account.id,
          categoryId: category.id,
          memo: '보존 $i',
        ),
      );
    }
  });
  tearDown(() => db.close());

  Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selectedMonthProvider.overrideWith((ref) => '2024-02'),
          typeFilterProvider.overrideWith((ref) => 'expense'),
          searchFilterProvider.overrideWith(
            (ref) => const TransactionFilter(q: '보존'),
          ),
        ],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    ).read(appRouterProvider).go('/transactions');
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
  }

  for (final layout in ['compact', 'wide', 'mobile']) {
    final mobile = layout == 'mobile';
    final size = mobile
        ? const Size(390, 844)
        : layout == 'compact'
        ? const Size(950, 850)
        : const Size(1600, 1000);
    for (final destination in ['budget', 'investments']) {
      testWidgets(
        '$layout transactions → $destination preserves source; title back is PC only',
        (tester) async {
          final container = await boot(tester, size);
          final source = mobile
              ? find.byType(MobileTransactionsScreen)
              : find.byType(TransactionsScreen);
          final originalElement = tester.element(source);
          ScrollPosition? listPosition;
          double? originalOffset;
          if (!mobile) {
            final amount = find.byKey(
              const ValueKey('desktop-transactions-inline-amount'),
            );
            await tester.ensureVisible(amount);
            await tester.enterText(amount, '4321');
            final list = find.byKey(
              const ValueKey('desktop-transactions-list-scroll'),
            );
            await tester.drag(list, const Offset(0, -220));
            await tester.pumpAndSettle();
            listPosition = tester
                .state<ScrollableState>(
                  find
                      .descendant(of: list, matching: find.byType(Scrollable))
                      .first,
                )
                .position;
            originalOffset = listPosition.pixels;
            expect(originalOffset, greaterThan(0));
          }
          final button = find.byKey(
            ValueKey(
              '${mobile ? 'mobile' : 'desktop'}-transactions-$destination-button',
            ),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          final router = container.read(appRouterProvider);
          if (mobile) {
            expect(find.byType(PageBackButton), findsNothing);
            expect(find.byTooltip('뒤로가기'), findsNothing);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          } else {
            expect(
              GoRouterState.of(
                tester.element(find.byType(PageBackButton)),
              ).matchedLocation,
              '/$destination',
            );
            expect(router.canPop(), isTrue);
            final back = find.byTooltip('뒤로가기');
            expect(back, findsOneWidget);
            // The chevron belongs to the same heading row as the page title.
            final heading = find
                .ancestor(of: back, matching: find.byType(Row))
                .first;
            final title = find.descendant(
              of: heading,
              matching: find.text(destination == 'budget' ? '예산' : '투자'),
            );
            expect(title, findsOneWidget);
            // One title only; tapping its text must never navigate back.
            await tester.tap(title);
            await tester.pumpAndSettle();
            expect(
              GoRouterState.of(
                tester.element(find.byType(PageBackButton)),
              ).matchedLocation,
              '/$destination',
            );
            expect(
              tester.getCenter(back).dx,
              lessThan(tester.getCenter(title).dx),
            );
            await tester.tap(
              find.descendant(
                of: back,
                matching: find.byIcon(Icons.chevron_left),
              ),
            );
            await tester.pumpAndSettle();
          }
          expect(
            router.routeInformationProvider.value.uri.path,
            '/transactions',
          );
          expect(tester.element(source), same(originalElement));
          expect(container.read(selectedMonthProvider), '2024-02');
          expect(container.read(typeFilterProvider), 'expense');
          expect(container.read(searchFilterProvider).q, '보존');
          if (!mobile) {
            expect(listPosition!.pixels, originalOffset);
            expect(
              tester
                  .widget<TextField>(
                    find.byKey(
                      const ValueKey('desktop-transactions-inline-amount'),
                    ),
                  )
                  .controller!
                  .text,
              '4,321',
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(
          mobile ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
    }
  }

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} direct budget/investment entry hides unavailable back actions',
      (tester) async {
        final container = await boot(
          tester,
          mobile ? const Size(390, 844) : const Size(1400, 1000),
        );
        final router = container.read(appRouterProvider);
        for (final destination in ['budget', 'investments']) {
          router.go('/$destination');
          await tester.pumpAndSettle();
          expect(router.canPop(), isFalse);
          expect(find.byTooltip('뒤로가기'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
      variant: TargetPlatformVariant.only(
        mobile ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }
}
