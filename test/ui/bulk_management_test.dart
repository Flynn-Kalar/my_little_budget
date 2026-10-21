import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/tag_category_links.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/ui/desktop/accounts/accounts_screen.dart';
import 'package:my_little_budget/ui/desktop/budget/budget_screen.dart';
import 'package:my_little_budget/ui/desktop/calendar/calendar_screen.dart';
import 'package:my_little_budget/ui/desktop/investments/investments_screen.dart';
import 'package:my_little_budget/ui/desktop/notes/notes_screen.dart';
import 'package:my_little_budget/ui/desktop/settings/categories_screen.dart';
import 'package:my_little_budget/ui/desktop/settings/recurring_screen.dart';
import 'package:my_little_budget/ui/desktop/settings/tags_screen.dart';
import 'package:my_little_budget/ui/desktop/settings/transaction_presets_screen.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/budget/mobile_budget_screen.dart';
import 'package:my_little_budget/ui/mobile/calendar/mobile_calendar_screen.dart';
import 'package:my_little_budget/ui/mobile/investments/mobile_investments_screen.dart';
import 'package:my_little_budget/ui/mobile/notes/mobile_notes_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_categories_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_recurring_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_tags_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_transaction_presets_screen.dart';
import 'package:my_little_budget/ui/mobile/responsive_page.dart';
import 'package:my_little_budget/ui/shared/bulk_manage_button.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> hold(WidgetTester tester, BulkEntity entity, int id) async {
  final row = find.byKey(ValueKey('bulk-row-${entity.name}-$id'));
  await reveal(tester, row);
  final rect = tester.getRect(row.first);
  await tester.longPressAt(
    rect.topLeft +
        Offset(
          rect.width > 160 ? 80 : rect.width / 2,
          rect.height > 50 ? 26 : rect.height / 2,
        ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
  expect(
    find.byKey(ValueKey('bulk-selection-toolbar-${entity.name}')),
    findsOneWidget,
  );
  expect(find.text('1개 선택'), findsOneWidget);
}

Future<void> mount(
  WidgetTester tester,
  AppDatabase db,
  Widget screen,
  bool mobile,
) async {
  await tester.binding.setSurfaceSize(
    mobile ? const Size(390, 844) : const Size(1100, 950),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: Scaffold(body: screen)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> cleanup(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
  await db.close();
  await tester.binding.setSurfaceSize(null);
}

Future<void> saveWait(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Future<int> seed(AppDatabase db, BulkEntity entity) async {
  return switch (entity) {
    BulkEntity.categories =>
      db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: '선택 카테고리',
              type: 'expense',
              color: const Value('#123456'),
            ),
          ),
    BulkEntity.tags => db.tagsDao.createTag('선택 태그', '#123456'),
    BulkEntity.accounts => (await db.accountsDao.getActiveAccounts()).first.id,
    BulkEntity.notes => db.notesDao.saveNote(title: '선택 메모', content: '읽을 내용'),
    BulkEntity.calendar => db.calendarEventsDao.saveEvent(
      title: '선택 일정',
      startAt: DateTime.now().add(const Duration(days: 2)),
      settings: const CalendarScheduleSettings(isDday: true),
    ),
    BulkEntity.budgets => db.budgetDao.createBudgetGroup(
      name: '선택 예산',
      month: currentMonthKey(),
      amount: 1000,
    ),
    BulkEntity.presets =>
      db
          .into(db.transactionPresets)
          .insert(
            TransactionPresetsCompanion.insert(
              name: const Value('선택 프리셋'),
              type: 'expense',
              amount: 100,
            ),
          ),
    BulkEntity.recurring =>
      db
          .into(db.recurringTransactions)
          .insert(
            RecurringTransactionsCompanion.insert(
              name: '선택 반복',
              accountId: Value(
                (await db.accountsDao.getActiveAccounts()).first.id,
              ),
              categoryId: Value(
                (await db.categoriesDao.getActiveCategories(
                  'expense',
                )).first.id,
              ),
              type: 'expense',
              amount: 100,
              frequency: 'monthly',
              startDate: currentDateKey(),
              dayOfMonth: const Value(1),
            ),
          ),
    BulkEntity.investments => db.investmentsDao.saveInvestment(
      draft: InvestmentDraft(
        side: 'buy',
        ticker: 'SELECTTEST',
        quantity: 1,
        totalAmount: 100,
        occurredOn: currentDateKey(),
        occurredTime: '09:00',
      ),
    ),
  };
}

Widget screenFor(BulkEntity entity, bool mobile) => switch ((entity, mobile)) {
  (BulkEntity.categories, false) => const CategoriesScreen(),
  (BulkEntity.categories, true) => const MobileCategoriesScreen(),
  (BulkEntity.tags, false) => const TagsScreen(),
  (BulkEntity.tags, true) => const MobileTagsScreen(),
  (BulkEntity.accounts, false) => const AccountsScreen(),
  (BulkEntity.accounts, true) => const MobileAccountsScreen(),
  (BulkEntity.notes, false) => const NotesScreen(),
  (BulkEntity.notes, true) => const MobileNotesScreen(),
  (BulkEntity.calendar, false) => const CalendarScreen(),
  (BulkEntity.calendar, true) => const MobileCalendarScreen(),
  (BulkEntity.budgets, false) => const BudgetScreen(),
  (BulkEntity.budgets, true) => const MobileBudgetScreen(),
  (BulkEntity.presets, false) => const TransactionPresetsScreen(),
  (BulkEntity.presets, true) => const MobileTransactionPresetsScreen(),
  (BulkEntity.recurring, false) => const RecurringScreen(),
  (BulkEntity.recurring, true) => const MobileRecurringScreen(),
  (BulkEntity.investments, false) => const InvestmentsScreen(),
  (BulkEntity.investments, true) => const MobileInvestmentsScreen(),
};
void main() {
  for (final mobile in [false, true]) {
    for (final entity in BulkEntity.values) {
      testWidgets(
        '${mobile ? 'mobile' : 'PC'} ${entity.name} long-press selects actual row without opening a route',
        (tester) async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          try {
            final id = await seed(db, entity);
            if (entity == BulkEntity.calendar) {
              await db.calendarEventsDao.saveEvent(
                title: '숨겨진 다음 해 일정',
                startAt: DateTime(DateTime.now().year + 1, 2, 1),
              );
            }
            await mount(tester, db, screenFor(entity, mobile), mobile);
            if (entity == BulkEntity.calendar) {
              await tap(tester, find.text('D-day').first);
            }
            if (entity == BulkEntity.investments) {
              await tap(
                tester,
                mobile
                    ? find.text('거래내역')
                    : find.byKey(const ValueKey('desktop-investments-tab-1')),
              );
            }
            expect(find.byKey(ValueKey('bulk-item-$id')), findsNothing);
            await hold(tester, entity, id);
            expect(
              tester
                  .widget<Checkbox>(find.byKey(ValueKey('bulk-item-$id')).first)
                  .value,
              isTrue,
            );
            await tap(
              tester,
              find.byKey(ValueKey('bulk-row-${entity.name}-$id')).first,
            );
            expect(find.text('0개 선택'), findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
            expect(
              find
                  .byType(TextField)
                  .evaluate()
                  .where(
                    (e) =>
                        (e.widget as TextField).decoration?.labelText == '제목',
                  ),
              isEmpty,
            );
            await tap(
              tester,
              find.byKey(const ValueKey('bulk-cancel-selection')),
            );
            expect(find.byKey(ValueKey('bulk-item-$id')), findsNothing);
            expect(
              find.byKey(ValueKey('bulk-selection-toolbar-${entity.name}')),
              findsNothing,
            );
            if (entity == BulkEntity.accounts) {
              final before = (await db.accountsDao.getActiveAccounts()).length;
              await hold(tester, entity, id);
              await tap(tester, find.widgetWithText(FilledButton, '보관'));
              await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
              await saveWait(tester);
              expect(
                (await db.accountsDao.getActiveAccounts()).length,
                before - 1,
              );
            }
            if (entity == BulkEntity.calendar) {
              await tap(tester, find.text('월간').first);
              await hold(tester, entity, id);
              await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
              await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
              expect(find.text('1개 선택'), findsOneWidget);
              await tap(
                tester,
                find.byKey(const ValueKey('bulk-cancel-selection')),
              );
            }
            expect(tester.takeException(), isNull);
          } finally {
            await cleanup(tester, db);
          }
        },
      );
    }
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} categories delete exactly the inline selection and retain it on confirmation cancel',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final a = await seed(db, BulkEntity.categories);
          final b = await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  name: '선택 카테고리 B',
                  type: 'expense',
                  color: const Value('#654321'),
                ),
              );
          final count = (await db.categoriesDao.getAllCategories()).length;
          await mount(
            tester,
            db,
            screenFor(BulkEntity.categories, mobile),
            mobile,
          );
          await hold(tester, BulkEntity.categories, a);
          await tap(tester, find.byKey(ValueKey('bulk-item-$b')));
          expect(find.text('2개 선택'), findsOneWidget);
          await tap(tester, find.widgetWithText(FilledButton, '삭제'));
          await tap(tester, find.text('취소'));
          expect(find.text('2개 선택'), findsOneWidget);
          expect((await db.categoriesDao.getAllCategories()).length, count);
          await tap(tester, find.widgetWithText(FilledButton, '삭제'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await saveWait(tester);
          expect((await db.categoriesDao.getAllCategories()).length, count - 2);
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await cleanup(tester, db);
        }
      },
    );
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} inline tag category assignment exits selection and stays on tag page',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final a = await seed(db, BulkEntity.tags),
              b = await db.tagsDao.createTag('둘째 태그', '#654321');
          final category = (await db.categoriesDao.getActiveCategories(
            'expense',
          )).first;
          await mount(tester, db, screenFor(BulkEntity.tags, mobile), mobile);
          await hold(tester, BulkEntity.tags, a);
          await tap(tester, find.byKey(ValueKey('bulk-item-$b')));
          await tap(tester, find.widgetWithText(FilledButton, '카테고리 지정'));
          await tap(
            tester,
            find.byKey(ValueKey('tag-category-${category.id}')),
          );
          await tap(tester, find.widgetWithText(FilledButton, '적용'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await saveWait(tester);
          expect(
            (await db.tagsDao.getTags()).every(
              (t) =>
                  readTagCategoryIds(t.categoryIdsJson).contains(category.id),
            ),
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('bulk-selection-toolbar-tags')),
            findsNothing,
          );
          expect(find.text('태그 관리'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await cleanup(tester, db);
        }
      },
    );
  }
  testWidgets(
    'narrow fixed toolbar stays reachable after scrolling and failed batch retains all selections',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final categories = (await db.categoriesDao.getActiveCategories(
          'expense',
        )).take(2).toList();
        await db.budgetDao.createBudgetGroup(
          name: '사용 중',
          month: currentMonthKey(),
          amount: 100,
          categoryIds: [categories.last.id],
        );
        await tester.binding.setSurfaceSize(const Size(320, 600));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: Scaffold(
                body: ListView(
                  children: [
                    BulkSelectionToolbar(
                      entity: BulkEntity.categories,
                      items: [
                        for (final c in categories) BulkItem(c.id, c.name),
                      ],
                    ),
                    const SizedBox(height: 1000),
                    for (final c in categories)
                      ListTile(
                        title: Text(c.name),
                      ).bulkSelectable(BulkEntity.categories, c.id),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await hold(tester, BulkEntity.categories, categories.first.id);
        await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
        await tap(tester, find.widgetWithText(FilledButton, '삭제'));
        await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
        await saveWait(tester);
        expect(find.text('2개 선택'), findsOneWidget);
        expect(find.textContaining('선택한 항목은 모두 유지했습니다.'), findsOneWidget);
        expect(
          (await db.categoriesDao.getAllCategories())
              .where((c) => categories.any((before) => before.id == c.id))
              .length,
          2,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, db);
      }
    },
  );
  testWidgets(
    'mobile last investment inline deletion refreshes annual results',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final id = await seed(db, BulkEntity.investments);
        await mount(tester, db, const MobileInvestmentsScreen(), true);
        await tap(tester, find.text('거래내역'));
        await hold(tester, BulkEntity.investments, id);
        await tap(tester, find.widgetWithText(FilledButton, '삭제'));
        await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
        await saveWait(tester);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
        await tester.pumpAndSettle();
        await tap(tester, find.text('연'));
        expect(find.text('SELECTTEST'), findsNothing);
        expect(
          await db.investmentsDao.listInvestmentsByYear(DateTime.now().year),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, db);
      }
    },
  );

  testWidgets('mobile back cancels inline selection before navigating home', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await seed(db, BulkEntity.notes);
    final router = GoRouter(
      initialLocation: '/notes',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('홈 테스트')),
        ),
        GoRoute(
          path: '/notes',
          builder: (_, _) => const ResponsivePage(
            desktop: NotesScreen(),
            mobile: MobileNotesScreen(),
          ),
        ),
      ],
    );
    try {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await hold(tester, BulkEntity.notes, id);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/notes');
      expect(
        find.byKey(const ValueKey('bulk-selection-toolbar-notes')),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
    } finally {
      await cleanup(tester, db);
      router.dispose();
    }
  });
}
