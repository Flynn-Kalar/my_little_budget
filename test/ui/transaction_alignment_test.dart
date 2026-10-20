import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/ui/desktop/transactions/transactions_screen.dart';

void main() {
  testWidgets(
    'desktop transaction gutters align summaries, dates and cards without clipping large amounts',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final date = currentDateKey();
      const largeAmount = 999999999999999;
      final rows = [
        TransactionRow(
          id: 1,
          type: 'expense',
          occurredOn: date,
          occurredTime: '12:00',
          amount: largeAmount,
          memo: '아주 긴 거래 메모가 화면 바깥으로 넘쳐서는 안 됩니다',
          categoryName: '긴 이름의 카테고리입니다',
          accountName: '긴 이름의 결제 계좌입니다',
          tags: const [
            TransactionTagInfo(
              id: 1,
              name: '가로 영역을 넘길 만큼 아주 긴 태그 이름입니다',
              color: '#15966A',
            ),
          ],
        ),
        TransactionRow(
          id: 2,
          type: 'income',
          occurredOn: date,
          occurredTime: '13:00',
          amount: largeAmount,
        ),
        TransactionRow(
          id: 3,
          type: 'transfer',
          occurredOn: date,
          occurredTime: '14:00',
          amount: largeAmount,
          fromAccountName: '이름이 긴 출금 계좌',
          toAccountName: '이름이 긴 입금 계좌',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            transactionsListProvider.overrideWith((ref) async => rows),
            monthlySummaryProvider.overrideWith(
              (ref) async => const MonthlySummary(largeAmount, largeAmount),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: TransactionsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final summary = find.byKey(
        const ValueKey('desktop-transactions-summary-bar'),
      );
      final header = find.byKey(
        ValueKey('desktop-transactions-date-header-$date'),
      );
      final row = find.byKey(const ValueKey('desktop-transaction-row-1'));
      final amount = find.descendant(
        of: row,
        matching: find.text('-${formatKRW(largeAmount)}'),
      );
      final scroll = find.byKey(
        const ValueKey('desktop-transactions-list-scroll'),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(summary).dx, 16);
      expect(tester.getTopLeft(header).dx, tester.getTopLeft(summary).dx);
      expect(tester.getTopRight(header).dx, tester.getTopRight(summary).dx);
      expect(
        tester
            .getTopRight(
              find.byKey(ValueKey('desktop-transactions-date-transfer-$date')),
            )
            .dx,
        tester.getTopRight(header).dx,
      );
      expect(tester.getTopLeft(row).dx, tester.getTopLeft(summary).dx);
      expect(tester.getTopRight(row).dx, tester.getTopRight(summary).dx);
      expect(tester.getTopLeft(row).dx - tester.getTopLeft(scroll).dx, 16);
      expect(tester.getTopRight(scroll).dx - tester.getTopRight(row).dx, 16);
      expect(
        tester.getTopRight(amount).dx,
        lessThan(tester.getTopRight(row).dx - 12),
      );
      expect(
        tester.widget<Text>(amount).overflow,
        isNot(TextOverflow.ellipsis),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
