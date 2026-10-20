import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/tag_category_links.dart';
import 'package:my_little_budget/features/categories/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/ui/desktop/settings/categories_screen.dart';
import 'package:my_little_budget/ui/desktop/settings/tags_screen.dart';
import 'package:my_little_budget/ui/desktop/accounts/accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_categories_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_tags_screen.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/investments/mobile_investments_screen.dart';
import 'package:my_little_budget/ui/shared/bulk_manage_button.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> settleMutation(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
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

void main() {
  testWidgets(
    'mobile investment last-item batch deletion refreshes annual data as well as monthly data',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        await db.investmentsDao.saveInvestment(
          draft: InvestmentDraft(
            side: 'buy',
            occurredOn: currentDateKey(),
            occurredTime: '09:00',
            ticker: 'BULKTEST',
            quantity: 1,
            totalAmount: 100,
          ),
        );
        await mount(tester, db, const MobileInvestmentsScreen(), true);
        await tap(tester, find.text('거래내역'));
        await tap(
          tester,
          find.byKey(const ValueKey('bulk-select-investments')),
        );
        await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
        await tap(tester, find.widgetWithText(FilledButton, '삭제'));
        await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
        await settleMutation(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
        await tester.pumpAndSettle();
        await tap(tester, find.text('연'));
        expect(find.text('BULKTEST'), findsNothing);
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
  for (final mobile in [false, true]) {
    final platform = mobile ? 'mobile' : 'PC';
    testWidgets(
      '$platform categories select filtered results, cancel and delete only selected',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          for (final name in ['일괄 카테고리 A', '일괄 카테고리 B']) {
            await db.categoriesDao.saveCategory(
              draft: CategoryDraft(
                name: name,
                type: 'expense',
                color: '#123456',
              ),
            );
          }
          final before = (await db.categoriesDao.getAllCategories()).length;
          await mount(
            tester,
            db,
            mobile ? const MobileCategoriesScreen() : const CategoriesScreen(),
            mobile,
          );
          await tap(
            tester,
            find.byKey(const ValueKey('bulk-select-categories')),
          );
          await tester.enterText(find.byType(TextField).last, '일괄 카테고리');
          await tester.pumpAndSettle();
          await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
          expect(find.text('2개 선택'), findsOneWidget);
          await tap(tester, find.widgetWithText(FilledButton, '삭제'));
          await tap(tester, find.text('취소'));
          expect((await db.categoriesDao.getAllCategories()).length, before);
          await tap(tester, find.widgetWithText(FilledButton, '삭제'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await settleMutation(tester);
          expect(
            (await db.categoriesDao.getAllCategories()).length,
            before - 2,
          );
          expect(find.text('일괄 카테고리 A'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await cleanup(tester, db);
        }
      },
    );

    testWidgets(
      '$platform tags assign categories to selected tags and delete without touching others',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final categories = await db.categoriesDao.getActiveCategories(
            'expense',
          );
          final a = await db.tagsDao.createTag(
            'A',
            '#123456',
            categoryIds: [categories[0].id],
          );
          final b = await db.tagsDao.createTag('B', '#654321');
          await db.tagsDao.createTag('C', '#456789');
          await mount(
            tester,
            db,
            mobile ? const MobileTagsScreen() : const TagsScreen(),
            mobile,
          );
          await tap(tester, find.byKey(const ValueKey('bulk-select-tags')));
          for (final id in [a, b]) {
            await tap(tester, find.byKey(ValueKey('bulk-item-$id')));
          }
          await tap(tester, find.widgetWithText(FilledButton, '카테고리 지정'));
          await tap(
            tester,
            find.byKey(ValueKey('tag-category-${categories[1].id}')),
          );
          await tap(tester, find.widgetWithText(FilledButton, '적용'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await settleMutation(tester);
          final tags = await db.tagsDao.getTags();
          expect(
            readTagCategoryIds(
              tags.firstWhere((t) => t.id == a).categoryIdsJson,
            ),
            unorderedEquals([categories[0].id, categories[1].id]),
          );
          expect(
            readTagCategoryIds(
              tags.firstWhere((t) => t.id == b).categoryIdsJson,
            ),
            [categories[1].id],
          );
          expect(tags.singleWhere((t) => t.name == 'C').categoryIdsJson, '[]');
          await tap(tester, find.byKey(const ValueKey('bulk-select-tags')));
          for (final id in [a, b]) {
            await tap(tester, find.byKey(ValueKey('bulk-item-$id')));
          }
          await tap(tester, find.widgetWithText(FilledButton, '삭제'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await settleMutation(tester);
          expect((await db.tagsDao.getTags()).single.name, 'C');
          expect(find.text('#A'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await cleanup(tester, db);
        }
      },
    );

    testWidgets(
      '$platform accounts archive selected items and refresh active and archived lists',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final accounts = await db.accountsDao.getActiveAccounts();
          await mount(
            tester,
            db,
            mobile ? const MobileAccountsScreen() : const AccountsScreen(),
            mobile,
          );
          await tap(tester, find.byKey(const ValueKey('bulk-select-accounts')));
          for (final account in accounts.take(2)) {
            await tap(tester, find.byKey(ValueKey('bulk-item-${account.id}')));
          }
          expect(find.widgetWithText(FilledButton, '삭제'), findsNothing);
          await tap(tester, find.widgetWithText(FilledButton, '보관'));
          await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
          await settleMutation(tester);
          expect(
            (await db.accountsDao.getActiveAccounts()).length,
            accounts.length - 2,
          );
          expect(find.text(mobile ? '보관된 자산' : '보관된 자산 (2)'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await cleanup(tester, db);
        }
      },
    );
  }

  testWidgets(
    'narrow selection preserves hidden selections, limits select-all to search, and cancels without writes',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final a = await db.tagsDao.createTag('Alpha', '#123456');
        final b = await db.tagsDao.createTag('Beta', '#654321');
        await tester.binding.setSurfaceSize(const Size(320, 600));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: Scaffold(
                body: BulkManageButton(
                  entity: BulkEntity.tags,
                  items: [BulkItem(a, 'Alpha'), BulkItem(b, 'Beta')],
                ),
              ),
            ),
          ),
        );
        await tap(tester, find.byKey(const ValueKey('bulk-select-tags')));
        await tap(tester, find.byKey(ValueKey('bulk-item-$a')));
        await tester.enterText(find.byType(TextField).last, 'Beta');
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
        expect(find.text('2개 선택'), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
        expect(find.text('1개 선택'), findsOneWidget);
        await tap(tester, find.text('닫기'));
        expect((await db.tagsDao.getTags()).length, 2);
        await tap(tester, find.byKey(const ValueKey('bulk-select-tags')));
        expect(find.text('0개 선택'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, db);
      }
    },
  );

  testWidgets(
    'used category error retains the whole selection and fits with a narrow keyboard',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final categories = await db.categoriesDao.getActiveCategories(
          'expense',
        );
        await db.budgetDao.createBudgetGroup(
          name: '보호할 예산',
          month: '2026-10',
          amount: 100,
          categoryIds: [categories[1].id],
        );
        await tester.binding.setSurfaceSize(const Size(320, 600));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: const EdgeInsets.only(bottom: 200)),
                child: child!,
              ),
              home: Scaffold(
                body: BulkManageButton(
                  entity: BulkEntity.categories,
                  items: [
                    for (final category in categories.take(2))
                      BulkItem(category.id, category.name),
                  ],
                ),
              ),
            ),
          ),
        );
        await tap(tester, find.byKey(const ValueKey('bulk-select-categories')));
        await tap(tester, find.byKey(const ValueKey('bulk-select-all')));
        await tap(tester, find.widgetWithText(FilledButton, '삭제'));
        await tap(tester, find.byKey(const ValueKey('bulk-confirm')));
        await settleMutation(tester);
        expect(find.textContaining('선택한 항목은 모두 유지했습니다.'), findsOneWidget);
        expect(find.text('2개 선택'), findsOneWidget);
        final remaining = await db.categoriesDao.getAllCategories();
        expect(
          remaining.any((category) => category.id == categories[0].id),
          isTrue,
        );
        expect(
          remaining.any((category) => category.id == categories[1].id),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester, db);
      }
    },
  );
}
