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
    expect(find.text('검색·필터'), findsOneWidget);
    // 거래가 목록에 표시 (카테고리명 + 태그칩)
    expect(find.text(cat.name), findsWidgets);
    // 행의 태그칩 + 입력창 제안칩 양쪽에 나타남
    expect(find.text('#테스트태그'), findsWidgets);

    final scrollFinder = find.byKey(
      const ValueKey('desktop-transactions-list-scroll'),
    );
    final mainColumnFinder = find.byKey(
      const ValueKey('desktop-transactions-main-column'),
    );
    final summaryFinder = find.byKey(
      const ValueKey('desktop-transactions-summary-bar'),
    );
    final inlineEntryFinder = find.byKey(
      const ValueKey('desktop-transactions-inline-entry'),
    );
    final listWidthFinder = find.byKey(
      const ValueKey('desktop-transactions-list-width'),
    );
    final sidePanelFinder = find.byKey(
      const ValueKey('desktop-transactions-side-panel'),
    );
    expect(mainColumnFinder, findsOneWidget);
    expect(sidePanelFinder, findsOneWidget);
    expect(listWidthFinder, findsOneWidget);
    expect(tester.getSize(mainColumnFinder).width, 720);
    expect(tester.getSize(summaryFinder).width, 720);
    expect(tester.getSize(inlineEntryFinder).width, 720);
    expect(tester.getSize(scrollFinder).width, 720);
    expect(tester.getSize(listWidthFinder).width, 720);
    expect(
      tester.getTopLeft(listWidthFinder).dx,
      tester.getTopLeft(scrollFinder).dx,
    );
    expect(
      tester.getTopLeft(sidePanelFinder).dx,
      greaterThan(tester.getTopRight(mainColumnFinder).dx),
    );

    final rowAmount = find.descendant(
      of: listWidthFinder,
      matching: find.text('-${formatKRW(12345)}'),
    );
    expect(rowAmount, findsOneWidget);
    expect(
      tester.getTopRight(rowAmount).dx,
      lessThan(tester.getTopRight(listWidthFinder).dx - 24),
    );

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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop-transactions-summary-bar')),
        matching: find.text('순수입'),
      ),
      findsOneWidget,
    );
    expect(find.text('검색·필터'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('desktop-transactions-summary-bar')),
      findsNothing,
    );
    expect(find.text('검색·필터'), findsNothing);
    expect(find.text('추가'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('desktop-transactions-collapse-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop-transactions-summary-bar')),
        matching: find.text('순수입'),
      ),
      findsOneWidget,
    );
    expect(find.text('검색·필터'), findsOneWidget);
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
    final filterButton = find.widgetWithText(OutlinedButton, '검색·필터');
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
    expect(search, findsOneWidget);
    expect(minAmount, findsOneWidget);
    expect(maxAmount, findsOneWidget);
    expect(account, findsOneWidget);
    expect(fromDate, findsOneWidget);
    expect(toDate, findsOneWidget);
  });

  testWidgets('PC 내역 화면: 1920 작업 영역에서 wide 컬럼을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(1920, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accId = (await db.accountsDao.getActiveAccounts()).first.id;
    final cat = (await db.categoriesDao.getActiveCategories('expense')).first;
    for (var i = 0; i < 8; i++) {
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 1000 + i,
          occurredOn: currentDateKey(),
          occurredTime: '12:00',
          accountId: accId,
          categoryId: cat.id,
          memo: 'wide-row-$i',
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

    final mainColumn = find.byKey(
      const ValueKey('desktop-transactions-main-column'),
    );
    final sidePanel = find.byKey(
      const ValueKey('desktop-transactions-side-panel'),
    );
    final listWidth = find.byKey(
      const ValueKey('desktop-transactions-list-width'),
    );

    expect(mainColumn, findsOneWidget);
    expect(sidePanel, findsOneWidget);
    expect(tester.getSize(mainColumn).width, 820);
    expect(tester.getSize(sidePanel).width, 360);
    expect(tester.getSize(listWidth).width, 820);
    expect(find.text('wide-row-0'), findsOneWidget);
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
    expect(_desktopDailyTransfer(firstDate, 1, 9999), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(
        find.byKey(const ValueKey('desktop-transactions-list-scroll')),
      ),
    );
    container.read(typeFilterProvider.notifier).state = 'expense';
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('desktop-transactions-date-income-$firstDate')),
      findsNothing,
    );
    expect(_desktopDailyExpense(firstDate, 1000), findsOneWidget);
    expect(
      find.byKey(ValueKey('desktop-transactions-date-income-$secondDate')),
      findsNothing,
    );
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

  testWidgets('PC 내역 화면: 미래 거래를 예정 거래로 분리하고 빠른 입력은 금액 우선이다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accountId = (await db.accountsDao.getActiveAccounts()).first.id;
    final categoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;
    final now = DateTime.now();
    final future = DateTime(now.year, now.month, now.day + 1);
    final futureDate = toDateKey(future);

    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 1234,
        occurredOn: futureDate,
        occurredTime: '12:00',
        accountId: accountId,
        categoryId: categoryId,
        memo: 'future-planned-row',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(
        find.byKey(const ValueKey('desktop-transactions-list-scroll')),
      ),
    );
    container.read(selectedMonthProvider.notifier).state = toMonthKey(future);
    await tester.pumpAndSettle();

    expect(find.text('예정 거래 1건'), findsOneWidget);
    expect(find.text('예정'), findsWidgets);
    expect(find.text('future-planned-row'), findsOneWidget);

    final amount = find.byKey(
      const ValueKey('desktop-transactions-inline-amount'),
    );
    final date = find.byKey(const ValueKey('desktop-transactions-inline-date'));
    expect(amount, findsOneWidget);
    expect(date, findsOneWidget);
    expect(tester.getTopLeft(amount).dy, lessThan(tester.getTopLeft(date).dy));
  });

  testWidgets('PC 내역 화면: 이체 제목과 태그 접기를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accounts = await db.accountsDao.getActiveAccounts();
    final categoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;

    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'transfer',
        amount: 50000,
        occurredOn: currentDateKey(),
        occurredTime: '12:00',
        fromAccountId: accounts[0].id,
        toAccountId: accounts[1].id,
        memo: 'transfer-title-row',
      ),
    );
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 2000,
        occurredOn: currentDateKey(),
        occurredTime: '13:00',
        accountId: accounts[0].id,
        categoryId: categoryId,
        memo: 'tag-fold-row',
      ),
      tagNames: const ['태그A', '태그B', '태그C'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('${accounts[0].name} → ${accounts[1].name}'),
      findsOneWidget,
    );
    expect(find.text('transfer-title-row'), findsOneWidget);
    expect(find.text('#태그A'), findsOneWidget);
    expect(find.text('#태그B'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('#태그C'), findsNothing);
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

Finder _desktopDailyTransfer(String date, int count, int amount) {
  return find.descendant(
    of: find.byKey(ValueKey('desktop-transactions-date-transfer-$date')),
    matching: find.text('이체 $count건 · ${formatKRW(amount)}'),
  );
}
