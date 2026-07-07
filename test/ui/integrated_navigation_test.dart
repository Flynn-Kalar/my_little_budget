import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';

void main() {
  testWidgets('데스크톱 예산은 내역 헤더에서 진입한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
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

    const budgetButton = ValueKey('desktop-transactions-budget-button');
    expect(find.byKey(budgetButton), findsOneWidget);
    expect(find.text('예산 보기'), findsOneWidget);

    await tester.tap(find.byKey(budgetButton));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('my_little_budget')));
    expect(router.routeInformationProvider.value.uri.path, '/budget');

    router.go('/transactions');
    await tester.pumpAndSettle();

    const investmentsButton = ValueKey(
      'desktop-transactions-investments-button',
    );
    expect(find.byKey(investmentsButton), findsOneWidget);
    await tester.tap(find.byKey(investmentsButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/investments');
  });

  testWidgets('모바일 예산과 연간 통계는 각 페이지 헤더에서 진입한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
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

    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.map((item) => item.label), isNot(contains('예산')));
    expect(destinations.map((item) => item.label), isNot(contains('투자')));
    expect(destinations.map((item) => item.label), isNot(contains('캘린더')));

    const budgetButton = ValueKey('mobile-transactions-budget-button');
    expect(find.byKey(budgetButton), findsOneWidget);
    await tester.tap(find.byKey(budgetButton));
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    final router = GoRouter.of(tester.element(navigationBar));
    expect(
      find.byKey(const ValueKey('mobile-budget-copy-previous-button')),
      findsOneWidget,
    );
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(budgetButton), findsOneWidget);

    router.go('/transactions');
    await tester.pumpAndSettle();

    const investmentsButton = ValueKey(
      'mobile-transactions-investments-button',
    );
    expect(find.byKey(investmentsButton), findsOneWidget);
    await tester.tap(find.byKey(investmentsButton));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-investments-search-filter-bar')),
      findsOneWidget,
    );
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(investmentsButton), findsOneWidget);

    router.go('/stats');
    await tester.pumpAndSettle();

    const yearlyButton = ValueKey('mobile-stats-yearly-button');
    expect(find.byKey(yearlyButton), findsOneWidget);
    await tester.tap(find.byKey(yearlyButton));
    await tester.pumpAndSettle();
    expect(find.text('연간 통계'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(yearlyButton), findsOneWidget);
  });

  testWidgets('데스크톱 메모 헤더에서 통합 캘린더로 진입한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final router = GoRouter.of(tester.element(find.text('my_little_budget')));
    router.go('/notes');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    const calendarButton = ValueKey('desktop-notes-calendar-button');
    expect(find.byKey(calendarButton), findsOneWidget);
    await tester.tap(find.byKey(calendarButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('캘린더'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  testWidgets('모바일 메모 헤더에서 통합 캘린더로 진입한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/notes');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    const calendarButton = ValueKey('mobile-notes-calendar-button');
    expect(find.byKey(calendarButton), findsOneWidget);
    await tester.tap(find.byKey(calendarButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('캘린더'), findsWidgets);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(calendarButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
