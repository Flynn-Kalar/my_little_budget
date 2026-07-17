import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/recurring/validation.dart';

void main() {
  testWidgets('App boots and shows desktop sidebar', (tester) async {
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

    expect(find.text('my_little_budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MVP main routes render without exceptions', (tester) async {
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

    final routes = [
      '/transactions',
      '/accounts',
      '/budget',
      '/stats',
      '/stats/yearly',
      '/investments',
      '/notes',
      '/settings',
      '/settings/theme',
      '/settings/backup',
      '/settings/about',
    ];

    for (final route in routes) {
      final context = tester.element(find.text('my_little_budget').first);
      GoRouter.of(context).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });

  testWidgets('Mobile main routes render without exceptions', (tester) async {
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

    final routes = [
      '/transactions',
      '/accounts',
      '/budget',
      '/stats',
      '/stats/yearly',
      '/investments',
      '/notes',
      '/settings',
      '/settings/theme',
      '/settings/backup',
      '/settings/about',
    ];

    for (final route in routes) {
      final context = tester.element(find.byType(NavigationBar));
      GoRouter.of(context).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });

  testWidgets('Recurring backfill runs before visiting transactions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;

    await db.recurringDao.saveRecurring(
      draft: RecurringDraft(
        name: '앱 시작 반복',
        type: 'expense',
        amount: 1234,
        memo: '앱 시작 반복',
        frequency: 'monthly',
        occurredTime: '09:00',
        startDate: '${currentMonthKey()}-01',
        dayOfMonth: 1,
        accountId: account.id,
        categoryId: category.id,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    var rows = await db.transactionsDao.listTransactionsByMonth(
      currentMonthKey(),
    );
    for (var attempt = 0; attempt < 50 && rows.isEmpty; attempt++) {
      // Startup synchronization continues after the first settled frame. Pump
      // the event loop without starting the backfill directly from the test.
      await tester.pump(const Duration(milliseconds: 10));
      rows = await db.transactionsDao.listTransactionsByMonth(
        currentMonthKey(),
      );
    }

    final context = tester.element(find.text('my_little_budget').first);
    GoRouter.of(context).go('/budget');
    await tester.pumpAndSettle();

    expect(rows.map((row) => row.memo), contains('앱 시작 반복'));
  });
}
