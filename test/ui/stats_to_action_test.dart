import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart' as tx;
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import 'package:my_little_budget/features/budget/providers.dart';
import 'package:my_little_budget/router/app_router.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';
import 'package:my_little_budget/ui/mobile/transactions/mobile_transactions_screen.dart';

void main() {
  late AppDatabase db;
  late int category;
  late int otherCategory;
  late int taggedId;
  late int untaggedId;
  late int tagId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = (await db.accountsDao.getActiveAccounts()).first.id;
    final categories = await db.categoriesDao.getActiveCategories('expense');
    category = categories.first.id;
    otherCategory = categories[1].id;
    Future<int> add(String date, int cat, String memo, List<String> tags) =>
        db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: 10000,
            occurredOn: date,
            occurredTime: '12:00',
            accountId: account,
            categoryId: cat,
            memo: memo,
          ),
          tagNames: tags,
        );
    taggedId = await add('2024-02-29', category, '선택한 범위', ['점심']);
    untaggedId = await add('2024-02-28', category, '태그 없는 범위', []);
    await add('2024-01-01', category, '다른 달', ['점심']);
    await add('2024-02-29', otherCategory, '다른 분류', ['점심']);
    tagId = (await db.tagsDao.getTags()).single.id;
  });
  tearDown(() => db.close());

  Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          statsMonthProvider.overrideWith((ref) => '2024-02'),
        ],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    // Navigation must replace stale account, amount, search and type filters.
    container.read(tx.typeFilterProvider.notifier).state = 'income';
    container.read(tx.searchFilterProvider.notifier).state =
        const TransactionFilter(q: '일치하지 않음', maxAmount: 1, accountId: 9999);
    container.read(appRouterProvider).go('/stats');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'compact PC overview expands without losing the list or typed entry on resize',
    (tester) async {
      final container = await boot(tester, const Size(500, 760));
      container.read(tx.selectedMonthProvider.notifier).state = '2024-02';
      container.read(tx.typeFilterProvider.notifier).state = null;
      container.read(tx.searchFilterProvider.notifier).state =
          const TransactionFilter();
      container.read(appRouterProvider).go('/transactions');
      await tester.pumpAndSettle();
      final overview = find.byKey(
        const ValueKey('desktop-transactions-compact-overview'),
      );
      expect(overview, findsOneWidget);
      expect(find.text('월말 예상 순수입 -${formatKRW(30000)}'), findsOneWidget);
      final amount = find.byKey(
        const ValueKey('desktop-transactions-inline-amount'),
      );
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '12345');
      final toggle = find.byKey(
        const ValueKey('desktop-transactions-overview-toggle'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('다가오는 예정 거래'), findsOneWidget);
      final filter = find.text('검색·필터');
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      final list = find.byKey(
        const ValueKey('desktop-transactions-list-scroll'),
      );
      expect(tester.getSize(list).height, greaterThanOrEqualTo(140));
      expect(tester.takeException(), isNull);
      for (final width in [800.0, 1600.0, 500.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<TextField>(amount).controller!.text, '12,345');
        expect(tester.getSize(list).height, greaterThanOrEqualTo(140));
        expect(overview, width == 1600 ? findsNothing : findsOneWidget);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final selection in ['category', 'tag', 'untagged']) {
    testWidgets(
      'desktop $selection opens exactly the selected statistics range',
      (tester) async {
        final container = await boot(tester, const Size(1400, 1000));
        final categoryRow = find.byKey(
          ValueKey('desktop-stats-category-$category'),
        );
        await tester.ensureVisible(categoryRow);
        await tester.tap(categoryRow);
        await tester.pumpAndSettle();
        if (selection != 'category') {
          final tagRow = find.byKey(
            ValueKey(
              'desktop-stats-tag-${selection == 'tag' ? tagId : 'untagged'}',
            ),
          );
          await tester.ensureVisible(tagRow);
          await tester.tap(tagRow);
          await tester.pumpAndSettle();
        }
        final action = find.byKey(
          ValueKey(
            'stats-organize-$category-${selection == 'category'
                ? 'all'
                : selection == 'tag'
                ? tagId
                : 'untagged'}',
          ),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(TransactionsScreen), findsOneWidget);
        expect(container.read(tx.selectedMonthProvider), '2024-02');
        expect(container.read(tx.typeFilterProvider), 'expense');
        final filter = container.read(tx.searchFilterProvider);
        expect(filter.fromDate, '2024-02-01');
        expect(filter.toDate, '2024-02-29');
        expect(filter.categoryIds, [category]);
        expect(filter.q, isNull);
        expect(filter.maxAmount, isNull);
        expect(filter.accountId, isNull);
        expect(filter.untaggedOnly, selection == 'untagged');
        expect(filter.tagIds, selection == 'tag' ? [tagId] : null);
        final rows = await container.read(tx.transactionsListProvider.future);
        expect(
          rows.map((r) => r.id).toSet(),
          selection == 'category'
              ? {taggedId, untaggedId}
              : selection == 'tag'
              ? {taggedId}
              : {untaggedId},
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'budget navigation preserves the selected historical month',
    (tester) async {
      final container = await boot(tester, const Size(1000, 1000));
      final action = find.text('2024-02 예산 조정');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(container.read(budgetMonthProvider), '2024-02');
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/budget',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'mobile tag action closes nested sheets and opens matching editable rows',
    (tester) async {
      final container = await boot(tester, const Size(390, 844));
      final categoryRow = find.byKey(
        ValueKey('mobile-stats-category-$category'),
      );
      await tester.ensureVisible(categoryRow);
      await tester.tap(categoryRow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('태그 없음'));
      await tester.pumpAndSettle();
      final action = find.byKey(ValueKey('stats-organize-$category-untagged'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(MobileTransactionsScreen), findsOneWidget);
      expect(find.byTooltip('태그 비율로 돌아가기'), findsNothing);
      expect(find.textContaining('태그별 비율'), findsNothing);
      expect(container.read(tx.searchFilterProvider).untaggedOnly, isTrue);
      expect(
        (await container.read(tx.transactionsListProvider.future)).single.id,
        untaggedId,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
