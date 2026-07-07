import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/shared/investments_providers.dart';
import 'package:my_little_budget/ui/shared/transactions_providers.dart';

void main() {
  testWidgets('모바일 내역 검색과 필터가 한 행에서 동작한다', (tester) async {
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

    const searchKey = ValueKey('mobile-transactions-search-field');
    const filterKey = ValueKey('mobile-transactions-filter-button');
    final search = find.byKey(searchKey);
    final filter = find.byKey(filterKey);
    expect(search, findsOneWidget);
    expect(filter, findsOneWidget);
    expect(tester.getCenter(search).dy, tester.getCenter(filter).dy);
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(tester.element(search));
    await tester.enterText(search, '식비');
    await tester.pumpAndSettle();
    expect(container.read(searchFilterProvider).q, '식비');

    await tester.tap(
      find.byKey(const ValueKey('mobile-transactions-search-clear')),
    );
    await tester.pumpAndSettle();
    expect(container.read(searchFilterProvider).q, isNull);

    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey('mobile-transactions-type-filter-inline'),
        ),
        matching: find.text('지출'),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(typeFilterProvider), 'expense');

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('미태그만 보기'));
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    expect(container.read(searchFilterProvider).untaggedOnly, isTrue);
    expect(tester.widget<IconButton>(filter).isSelected, isTrue);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '초기화'));
    await tester.pumpAndSettle();
    expect(container.read(searchFilterProvider).untaggedOnly, isFalse);
    expect(tester.widget<IconButton>(filter).isSelected, isFalse);
  });

  testWidgets('모바일 투자 필터는 거래내역 탭에서만 동작한다', (tester) async {
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
    GoRouter.of(tester.element(find.byType(NavigationBar))).go('/investments');
    await tester.pumpAndSettle();

    const searchKey = ValueKey('mobile-investments-search-field');
    const filterKey = ValueKey('mobile-investments-filter-button');
    expect(find.byKey(searchKey), findsOneWidget);
    expect(find.byKey(filterKey), findsNothing);

    await tester.tap(find.text('거래내역'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(searchKey));
    await tester.pumpAndSettle();

    final search = find.byKey(searchKey);
    final filter = find.byKey(filterKey);
    expect(filter, findsOneWidget);
    expect(tester.getCenter(search).dy, tester.getCenter(filter).dy);
    expect(tester.takeException(), isNull);

    await tester.enterText(search, '삼성');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '삼성'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(search));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '매수'));
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    expect(container.read(investmentFilterProvider).side, 'buy');
    expect(tester.widget<IconButton>(filter).isSelected, isTrue);
    expect(find.widgetWithText(TextField, '삼성'), findsOneWidget);

    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '초기화'));
    await tester.pumpAndSettle();
    expect(container.read(investmentFilterProvider).isActive, isFalse);
    expect(tester.widget<IconButton>(filter).isSelected, isFalse);

    await tester.tap(find.text('보유종목'));
    await tester.pumpAndSettle();
    expect(find.byKey(searchKey), findsOneWidget);
    expect(find.byKey(filterKey), findsNothing);
  });
}
