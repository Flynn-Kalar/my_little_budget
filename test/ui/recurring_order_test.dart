import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/recurring/validation.dart';
import 'package:my_little_budget/ui/desktop/settings/recurring_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_recurring_screen.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} reorder cancels, saves and restores inactive items in custom positions',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        await tester.binding.setSurfaceSize(
          mobile ? const Size(390, 844) : const Size(1100, 900),
        );
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        try {
          final account = (await db.accountsDao.getActiveAccounts()).first;
          final category = (await db.categoriesDao.getActiveCategories(
            'expense',
          )).first;
          final ids = <int>[];
          for (final name in ['A', 'B', 'C']) {
            ids.add(
              await db.recurringDao.saveRecurring(
                draft: RecurringDraft(
                  name: name,
                  type: 'expense',
                  amount: 1000,
                  frequency: 'monthly',
                  dayOfMonth: 1,
                  occurredTime: '09:00',
                  startDate: '2026-10-01',
                  accountId: account.id,
                  categoryId: category.id,
                ),
              ),
            );
          }
          await db.recurringDao.toggleRecurringActive(ids.last, false);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appDatabaseProvider.overrideWithValue(db)],
              child: MaterialApp(
                home: Scaffold(
                  body: mobile
                      ? const MobileRecurringScreen()
                      : const RecurringScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tap(find.byKey(const ValueKey('recurring-order-button')));
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(ValueKey('recurring-order-up-${ids.first}')),
                )
                .onPressed,
            isNull,
          );
          await tap(find.byKey(ValueKey('recurring-order-up-${ids.last}')));
          await tap(find.text('취소'));
          expect(
            (await db.recurringDao.listRecurringTransactions()).map(
              (item) => item.recurring.id,
            ),
            ids,
          );
          await tap(find.byKey(const ValueKey('recurring-order-button')));
          await tap(find.byKey(ValueKey('recurring-order-up-${ids.last}')));
          await tap(find.byKey(ValueKey('recurring-order-up-${ids.last}')));
          await tap(find.byKey(const ValueKey('recurring-order-save')));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(
            (await db.recurringDao.listRecurringTransactions()).map(
              (item) => item.recurring.id,
            ),
            [ids.last, ids.first, ids[1]],
          );
          await tap(find.byKey(const ValueKey('recurring-order-button')));
          expect(
            tester
                .getTopLeft(
                  find.byKey(ValueKey('recurring-order-row-${ids.last}')),
                )
                .dy,
            lessThan(
              tester
                  .getTopLeft(
                    find.byKey(ValueKey('recurring-order-row-${ids.first}')),
                  )
                  .dy,
            ),
          );
          // Category-style inline controls replace the separate drag dialog.
          expect(find.byType(AlertDialog), findsNothing);
          await tap(find.byKey(ValueKey('recurring-order-up-${ids[1]}')));
          await tap(find.byKey(ValueKey('recurring-order-up-${ids[1]}')));
          await tap(find.byKey(const ValueKey('recurring-order-save')));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(
            (await db.recurringDao.listRecurringTransactions())
                .first
                .recurring
                .id,
            ids[1],
          );
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
