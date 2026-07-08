import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_account_detail_screen.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_categories_screen.dart';

void main() {
  testWidgets('모바일 자산 화면에서 보관된 자산을 복원할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final account = (await db.accountsDao.getActiveAccounts()).first;
    await db.accountsDao.archiveAccount(account.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileAccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('보관된 자산'), findsOneWidget);
    await tester.tap(find.text('복원'));
    await tester.pumpAndSettle();

    expect(await db.accountsDao.getArchivedAccounts(), isEmpty);
  });

  testWidgets('모바일 카테고리 화면에서 PC처럼 보관 항목을 복원한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    await db.categoriesDao.archiveCategory(category.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileCategoriesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('보관된 카테고리'), findsOneWidget);
    final menu = find.byType(PopupMenuButton<String>).last;
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('복원'));
    await tester.pumpAndSettle();

    final restored = await db.categoriesDao.getActiveCategories('expense');
    expect(restored.any((row) => row.id == category.id), isTrue);
  });

  testWidgets('모바일 자산 상세에서 PC와 동일하게 카테고리 필터를 적용한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final month = currentMonthKey();
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final categories = await db.categoriesDao.getActiveCategories('expense');
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 1000,
        occurredOn: '$month-01',
        occurredTime: '09:00',
        accountId: account.id,
        categoryId: categories[0].id,
        memo: 'mobile account filter target',
      ),
    );
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 2000,
        occurredOn: '$month-02',
        occurredTime: '09:00',
        accountId: account.id,
        categoryId: categories[1].id,
        memo: 'mobile account filter other',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: MobileAccountDetailScreen(accountId: account.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mobile account filter target'), findsOneWidget);
    expect(find.textContaining('mobile account filter other'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('mobile-account-detail-filter-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(categories[0].name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mobile account filter target'), findsOneWidget);
    expect(find.textContaining('mobile account filter other'), findsNothing);
  });

  testWidgets(
    'mobile account detail transaction rows can be edited and deleted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final month = currentMonthKey();
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final editId = await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 1000,
          occurredOn: '$month-03',
          occurredTime: '09:00',
          accountId: account.id,
          categoryId: category.id,
          memo: 'mobile account editable row',
        ),
      );
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 2000,
          occurredOn: '$month-04',
          occurredTime: '09:00',
          accountId: account.id,
          categoryId: category.id,
          memo: 'mobile account deletable row',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: MobileAccountDetailScreen(accountId: account.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('mobile account editable row'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, '1500');
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      final editedRows = await db.transactionsDao.listTransactionsByAccount(
        account.id,
      );
      final edited = editedRows.singleWhere((row) => row.id == editId);
      expect(edited.amount, 1500);

      await tester.tap(find.textContaining('mobile account deletable row'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      final rows = await db.transactionsDao.listTransactionsByAccount(
        account.id,
      );
      expect(
        rows.any((row) => row.memo == 'mobile account deletable row'),
        isFalse,
      );
    },
  );
}
