import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/accounts/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/accounts/account_detail_screen.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_account_detail_screen.dart';
import 'package:my_little_budget/ui/shared/account_transaction_month_header.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} account headers separate years/months and respect filtered and empty results',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        await tester.binding.setSurfaceSize(
          mobile ? const Size(390, 844) : const Size(1100, 950),
        );
        try {
          final account = (await db.accountsDao.getActiveAccounts()).first;
          final category = (await db.categoriesDao.getActiveCategories(
            'expense',
          )).first;
          for (final (date, time) in [
            ('2027-01-02', '12:00'),
            ('2027-01-02', '09:00'),
            ('2026-12-31', '09:00'),
            ('2026-12-01', '09:00'),
            ('2025-12-31', '09:00'),
          ]) {
            await db.transactionsDao.saveTransaction(
              draft: TransactionDraft(
                type: 'expense',
                amount: 100,
                occurredOn: date,
                occurredTime: time,
                categoryId: category.id,
                accountId: account.id,
              ),
            );
          }
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appDatabaseProvider.overrideWithValue(db)],
              child: MaterialApp(
                home: Scaffold(
                  body: mobile
                      ? MobileAccountDetailScreen(accountId: account.id)
                      : AccountDetailScreen(accountId: account.id),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccountTransactionMonthHeader), findsNWidgets(3));
          for (final label in ['2027년 1월', '2026년 12월', '2025년 12월']) {
            expect(find.text(label), findsOneWidget);
          }
          expect(
            tester.getTopLeft(find.text('2027년 1월')).dy,
            lessThan(tester.getTopLeft(find.text('2026년 12월')).dy),
          );
          expect(
            tester.getTopLeft(find.text('2026년 12월')).dy,
            lessThan(tester.getTopLeft(find.text('2025년 12월')).dy),
          );
          final prefix = mobile ? 'mobile' : 'desktop';
          expect(
            find.byKey(ValueKey('$prefix-account-month-2027-01')),
            findsOneWidget,
          );
          if (mobile) {
            expect(
              find.byKey(const ValueKey('mobile-account-transactions-heading')),
              findsOneWidget,
            );
            final day = find.byKey(
              const ValueKey('mobile-account-day-2027-01-02'),
            );
            expect(day, findsOneWidget);
            expect(
              tester.getTopLeft(find.text('2027년 1월')).dy,
              lessThan(tester.getTopLeft(day).dy),
            );
            expect(
              tester.widget<Text>(find.text('2027년 1월')).style!.fontSize,
              greaterThan(tester.widget<Text>(day).style!.fontSize!),
            );
          }
          final container = ProviderScope.containerOf(
            tester.element(find.byType(AccountTransactionMonthHeader).first),
          );
          container
              .read(accountDetailFilterProvider(account.id).notifier)
              .state = const AccountDetailFilter(
            fromDate: '2026-12-01',
            toDate: '2026-12-31',
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccountTransactionMonthHeader), findsOneWidget);
          expect(find.text('2026년 12월'), findsOneWidget);
          expect(find.text('2027년 1월'), findsNothing);
          container
              .read(accountDetailFilterProvider(account.id).notifier)
              .state = const AccountDetailFilter(
            fromDate: '2030-01-01',
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccountTransactionMonthHeader), findsNothing);
          if (mobile) {
            expect(
              find.byKey(const ValueKey('mobile-account-transactions-heading')),
              findsOneWidget,
            );
          } else {
            expect(find.text('초기 잔액'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pumpAndSettle();
          await db.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }
}
