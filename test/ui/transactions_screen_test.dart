import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/month_nav.dart';
import 'package:my_little_budget/ui/shared/transactions_providers.dart';

void main() {
  testWidgets('내역 화면: 거래 표시 + 행 클릭 시 편집 다이얼로그 + 필터 패널', (tester) async {
    // 데스크톱 크기 (기본 800×600 이면 행이 화면 밖으로 밀려남)
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accId = (await db.accountsDao.getActiveAccounts()).first.id;
    final cat = (await db.categoriesDao.getActiveCategories('expense')).first;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 12345,
        occurredOn: currentDateKey(),
        occurredTime: '00:00',
        accountId: accId,
        categoryId: cat.id,
      ),
      tagNames: const ['테스트태그'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 필터 패널 존재
    expect(find.text('필터'), findsOneWidget);
    // 거래가 목록에 표시 (카테고리명 + 태그칩)
    expect(find.text(cat.name), findsWidgets);
    // 행의 태그칩 + 입력창 제안칩 양쪽에 나타남
    expect(find.text('#테스트태그'), findsWidgets);

    // 행 클릭 → 편집 다이얼로그 (카테고리명의 InkWell 조상을 탭)
    final rowInk = find
        .ancestor(of: find.text(cat.name), matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(rowInk);
    await tester.pumpAndSettle();
    await tester.tap(rowInk);
    await tester.pumpAndSettle();
    expect(find.text('거래 편집'), findsOneWidget);
    expect(find.text('복사'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });

  testWidgets('PC 내역 화면: 상단 접기/펴기 상태를 전환한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonthNav), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-transactions-budget-button')),
      findsOneWidget,
    );
    expect(find.text('순수입'), findsOneWidget);
    expect(find.text('필터'), findsOneWidget);
    expect(find.text('추가'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('desktop-transactions-collapse-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonthNav), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-transactions-budget-button')),
      findsOneWidget,
    );
    expect(find.text('순수입'), findsNothing);
    expect(find.text('필터'), findsNothing);
    expect(find.text('추가'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('desktop-transactions-collapse-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('순수입'), findsOneWidget);
    expect(find.text('필터'), findsOneWidget);
    expect(find.text('추가'), findsOneWidget);
  });

  testWidgets('PC 내역 화면: 펼친 필터가 전체 폭 카드로 배치된다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final typeChip = find.widgetWithText(ChoiceChip, '전체');
    final filterButton = find.widgetWithText(OutlinedButton, '필터');
    expect(typeChip, findsOneWidget);
    expect(filterButton, findsOneWidget);
    expect(tester.getCenter(typeChip).dy, tester.getCenter(filterButton).dy);

    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    final filterRow = find.byKey(
      const ValueKey('desktop-transactions-filter-row'),
    );
    final expandedFilter = find.byKey(
      const ValueKey('desktop-transactions-expanded-filter'),
    );
    expect(expandedFilter, findsOneWidget);
    expect(
      tester.getTopLeft(expandedFilter).dy,
      greaterThan(tester.getBottomLeft(filterRow).dy),
    );
    expect(
      tester.getTopLeft(expandedFilter).dx,
      tester.getTopLeft(filterRow).dx,
    );
    expect(
      tester.getSize(expandedFilter).width,
      tester.getSize(filterRow).width,
    );

    final search = find.byKey(const ValueKey('transactions-search-field'));
    final minAmount = find.byKey(
      const ValueKey('transactions-min-amount-field'),
    );
    final maxAmount = find.byKey(
      const ValueKey('transactions-max-amount-field'),
    );
    final account = find.byKey(
      const ValueKey('transactions-account-filter-field'),
    );
    final fromDate = find.byKey(
      const ValueKey('transactions-from-date-filter-button'),
    );
    final toDate = find.byKey(
      const ValueKey('transactions-to-date-filter-button'),
    );
    final controlCenterY = tester.getCenter(search).dy;

    expect(tester.getCenter(minAmount).dy, controlCenterY);
    expect(tester.getCenter(maxAmount).dy, controlCenterY);
    expect(tester.getCenter(account).dy, controlCenterY);
    expect(tester.getCenter(fromDate).dy, controlCenterY);
    expect(tester.getCenter(toDate).dy, controlCenterY);
  });

  testWidgets('PC 내역 화면: 날짜 헤더에 일별 수입/지출 합계를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accounts = await db.accountsDao.getActiveAccounts();
    final accountId = accounts.first.id;
    final transferToAccountId = accounts[1].id;
    final incomeCategoryId = (await db.categoriesDao.getActiveCategories(
      'income',
    )).first.id;
    final expenseCategoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;

    final firstDate = currentDateKey();
    final now = DateTime.now();
    final secondDate = toDateKey(
      DateTime(now.year, now.month, now.day == 1 ? 2 : now.day - 1),
    );

    Future<void> save({
      required String type,
      required int amount,
      required String date,
      int? accountId,
      int? categoryId,
      int? fromAccountId,
      int? toAccountId,
    }) {
      return db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: type,
          amount: amount,
          occurredOn: date,
          occurredTime: '12:00',
          accountId: accountId,
          categoryId: categoryId,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          memo: 'desktop-daily-total-test',
        ),
      );
    }

    await save(
      type: 'income',
      amount: 1000,
      date: firstDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'income',
      amount: 2000,
      date: firstDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'expense',
      amount: 300,
      date: firstDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );
    await save(
      type: 'expense',
      amount: 700,
      date: firstDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );
    await save(
      type: 'transfer',
      amount: 9999,
      date: firstDate,
      fromAccountId: accountId,
      toAccountId: transferToAccountId,
    );
    await save(
      type: 'income',
      amount: 5000,
      date: secondDate,
      accountId: accountId,
      categoryId: incomeCategoryId,
    );
    await save(
      type: 'expense',
      amount: 4000,
      date: secondDate,
      accountId: accountId,
      categoryId: expenseCategoryId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(_desktopDailyIncome(firstDate, 3000), findsOneWidget);
    expect(_desktopDailyExpense(firstDate, 1000), findsOneWidget);
    expect(_desktopDailyIncome(secondDate, 5000), findsOneWidget);
    expect(_desktopDailyExpense(secondDate, 4000), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('desktop-transactions-date-header-$firstDate')),
        matching: find.textContaining(formatKRW(9999)),
      ),
      findsNothing,
    );

    final container = ProviderScope.containerOf(
      tester.element(
        find.byKey(const ValueKey('desktop-transactions-list-scroll')),
      ),
    );
    container.read(typeFilterProvider.notifier).state = 'expense';
    await tester.pumpAndSettle();

    expect(_desktopDailyIncome(firstDate, 0), findsOneWidget);
    expect(_desktopDailyExpense(firstDate, 1000), findsOneWidget);
    expect(_desktopDailyIncome(secondDate, 0), findsOneWidget);
    expect(_desktopDailyExpense(secondDate, 4000), findsOneWidget);
  });

  testWidgets('PC 내역 화면: 저장된 내역 목록만 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accId = (await db.accountsDao.getActiveAccounts()).first.id;
    final cat = (await db.categoriesDao.getActiveCategories('expense')).first;
    for (var i = 0; i < 40; i++) {
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 1000 + i,
          occurredOn: currentDateKey(),
          occurredTime: '12:00',
          accountId: accId,
          categoryId: cat.id,
          memo: 'scroll-row-$i',
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final scrollFinder = find.byKey(
      const ValueKey('desktop-transactions-list-scroll'),
    );
    final budgetFinder = find.byKey(
      const ValueKey('desktop-transactions-budget-button'),
    );
    final scrollableFinder = find.descendant(
      of: scrollFinder,
      matching: find.byType(Scrollable),
    );
    final beforeTop = tester.getTopLeft(budgetFinder);
    final scrollable = tester.state<ScrollableState>(scrollableFinder);

    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(scrollFinder, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(budgetFinder), beforeTop);
  });
}

Finder _desktopDailyIncome(String date, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('desktop-transactions-date-income-$date')),
    matching: find.text('수입 ${formatKRW(amount)}'),
  );
}

Finder _desktopDailyExpense(String date, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('desktop-transactions-date-expense-$date')),
    matching: find.text('지출 ${formatKRW(amount)}'),
  );
}
