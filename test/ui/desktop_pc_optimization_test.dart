import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/core/theme/theme_colors.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  Future<AppDatabase> pumpDesktopApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
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
    return db;
  }

  void goTo(WidgetTester tester, String route) {
    final context = tester.element(find.text('my_little_budget'));
    GoRouter.of(context).go(route);
  }

  testWidgets('PC 예산 화면: 예산 그룹을 2열로 배치하고 초과 금액을 표시한다', (tester) async {
    final db = await pumpDesktopApp(tester);
    final month = currentMonthKey();
    final accountId = (await db.accountsDao.getActiveAccounts()).first.id;
    final categories = await db.categoriesDao.getActiveCategories('expense');

    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 150000,
        occurredOn: currentDateKey(),
        occurredTime: '00:00',
        accountId: accountId,
        categoryId: categories[0].id,
      ),
    );
    final firstGroupId = await db.budgetDao.createBudgetGroup(
      name: '식비 압축',
      month: month,
      amount: 100000,
      categoryIds: [categories[0].id],
    );
    final secondGroupId = await db.budgetDao.createBudgetGroup(
      name: '생활 압축',
      month: month,
      amount: 200000,
      categoryIds: [categories[1].id],
    );

    goTo(tester, '/budget');
    await tester.pumpAndSettle();

    expect(find.text('예산 초과 ${formatKRW(50000)}'), findsOneWidget);

    final firstCard = find.byKey(
      ValueKey('desktop-budget-group-$firstGroupId'),
    );
    final secondCard = find.byKey(
      ValueKey('desktop-budget-group-$secondGroupId'),
    );
    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);
    expect(tester.getTopLeft(firstCard).dy, tester.getTopLeft(secondCard).dy);
    expect(
      tester.getTopLeft(secondCard).dx,
      greaterThan(tester.getTopLeft(firstCard).dx),
    );
  });

  testWidgets('PC 자산 화면: 총자산/총부채/순자산과 제외 계좌 안내를 표시한다', (tester) async {
    final db = await pumpDesktopApp(tester);
    await db.accountsDao.saveAccount(
      draft: const AccountDraft(
        name: '제외 테스트',
        kind: 'bank',
        initialBalance: 123456,
        color: '#94a3b8',
        excludeFromTotal: true,
        isInvestment: false,
      ),
      currentBalance: 123456,
    );

    goTo(tester, '/accounts');
    await tester.pumpAndSettle();

    expect(find.text('총자산'), findsOneWidget);
    expect(find.text('총부채'), findsOneWidget);
    expect(find.text('총 순자산'), findsOneWidget);
    expect(find.textContaining('총액에서 제외한 계좌'), findsOneWidget);
  });

  testWidgets('PC 통계 화면: 원화 포맷과 최근 12개월 영역을 렌더링한다', (tester) async {
    final db = await pumpDesktopApp(tester);
    final accountId = (await db.accountsDao.getActiveAccounts()).first.id;
    final incomeCategoryId = (await db.categoriesDao.getActiveCategories(
      'income',
    )).first.id;
    final expenseCategoryId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;

    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'income',
        amount: 2139650,
        occurredOn: currentDateKey(),
        occurredTime: '00:00',
        accountId: accountId,
        categoryId: incomeCategoryId,
      ),
    );
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 705124,
        occurredOn: currentDateKey(),
        occurredTime: '00:00',
        accountId: accountId,
        categoryId: expenseCategoryId,
      ),
    );

    goTo(tester, '/stats');
    await tester.pumpAndSettle();

    expect(find.text('최근 12개월 추세'), findsOneWidget);
    expect(find.text(formatKRW(2139650)), findsWidgets);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData[2].color, defaultTheme.warning);
    final tooltip = chart.data.lineTouchData.touchTooltipData;
    expect(tooltip.fitInsideHorizontally, isTrue);
    expect(tooltip.fitInsideVertically, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PC 메모/캘린더 화면: 데스크톱 폭에서 overflow 없이 렌더링한다', (tester) async {
    final db = await pumpDesktopApp(tester);
    final month = parseMonthKey(currentMonthKey());
    await db.calendarEventsDao.saveEvent(
      title: '매일 반복 테스트',
      startAt: DateTime(month.year, month.month, 1, 9),
      schedule: const NoteScheduleDraft(type: NoteScheduleType.daily),
    );

    goTo(tester, '/notes');
    await tester.pumpAndSettle();
    expect(find.text('메모장'), findsOneWidget);
    expect(tester.takeException(), isNull);

    goTo(tester, '/calendar');
    await tester.pumpAndSettle();
    expect(find.text('캘린더'), findsWidgets);
    expect(find.textContaining('반복'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
  });
}
