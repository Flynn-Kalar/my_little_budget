import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/mobile/stats/mobile_stats_screen.dart';

void main() {
  testWidgets(
    'category opens month-scoped tag ratios including untagged spending',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final categories = await db.categoriesDao.getActiveCategories('expense');
      Future<void> expense(
        int amount,
        String date,
        int categoryId,
        List<String> tags,
      ) async {
        await db.transactionsDao.saveTransaction(
          draft: TransactionDraft(
            type: 'expense',
            amount: amount,
            occurredOn: date,
            occurredTime: '12:00',
            accountId: account.id,
            categoryId: categoryId,
          ),
          tagNames: tags,
        );
      }

      await expense(30000, '2026-10-01', categories.first.id, ['선택한 태그']);
      await expense(10000, '2026-10-02', categories.first.id, []);
      await expense(90000, '2026-09-01', categories.first.id, ['다른 범위 태그']);
      await expense(20000, '2026-10-01', categories[1].id, ['다른 범위 태그']);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            statsMonthProvider.overrideWith((ref) => '2026-10'),
          ],
          child: const MaterialApp(home: MobileStatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final category = find.byKey(
        ValueKey('mobile-stats-category-${categories.first.id}'),
      );
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(find.text('${categories.first.name} · 태그별 비율'), findsOneWidget);
      expect(find.text('#선택한 태그'), findsOneWidget);
      expect(find.text('태그 없음'), findsOneWidget);
      expect(find.text('#다른 범위 태그'), findsNothing);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text(formatKRW(30000)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('태그 합계'), findsNothing);
      final other = find.byKey(
        ValueKey('mobile-stats-category-${categories[1].id}'),
      );
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('#다른 범위 태그'), findsOneWidget);
      expect(find.text('#선택한 태그'), findsNothing);
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
