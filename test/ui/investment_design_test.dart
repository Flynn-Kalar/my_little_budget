import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/investments/manual_prices.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/ui/desktop/investments/investments_screen.dart';

void main() {
  for (final width in [650.0, 1440.0]) {
    testWidgets(
      'PC investment $width: portfolio, valuation, tabs and filtering',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
        });
        for (final ticker in ['삼성전자', 'AAPL']) {
          await db.investmentsDao.saveInvestment(
            draft: InvestmentDraft(
              side: 'buy',
              occurredOn: currentDateKey(),
              occurredTime: '12:00',
              ticker: ticker,
              quantity: 10,
              totalAmount: 700000,
            ),
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const Scaffold(body: InvestmentsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('보유 종목 2'), findsOneWidget);
        expect(find.text('현재가'), findsOneWidget);
        expect(find.text('월간 투자 거래'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(InvestmentsScreen)),
        );
        await container
            .read(investmentManualPricesProvider.notifier)
            .setPrice('삼성전자', 74000);
        await tester.pumpAndSettle();
        expect(find.text('+${formatKRW(40000)}'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('holding-row-삼성전자')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('holding-details-삼성전자')),
          findsOneWidget,
        );
        // Dense tables remain horizontally scrollable in a narrow desktop window.
        final priceButton = find.byKey(const ValueKey('holding-price-삼성전자'));
        await tester.ensureVisible(priceButton);
        await tester.pumpAndSettle();
        await tester.tap(priceButton);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('investment-current-price')),
          '-1',
        );
        await tester.tap(find.byKey(const ValueKey('investment-price-save')));
        await tester.pumpAndSettle();
        expect(find.textContaining('이하로 입력하세요.'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('investment-current-price')),
          '65,000',
        );
        await tester.tap(find.byKey(const ValueKey('investment-price-save')));
        await tester.pumpAndSettle();
        expect(
          container.read(investmentManualPricesProvider).requireValue['삼성전자'],
          65000,
        );
        expect(find.text(formatKRW(-50000)), findsWidgets);
        // Valuation never modifies purchases or their cost basis.
        expect(
          (await db.investmentsDao.listCurrentHoldings()).first.totalCost,
          700000,
        );
        expect(
          await db.investmentsDao.listInvestmentsByMonth(currentMonthKey()),
          hasLength(2),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('desktop-investments-tab-1')),
        );
        await tester.tap(
          find.byKey(const ValueKey('desktop-investments-tab-1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('월간 투자 거래'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('investment-ticker-filter')),
          'AAPL',
        );
        await tester.pumpAndSettle();
        expect(find.text('삼성전자'), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('desktop-investments-tab-0')),
        );
        await tester.pumpAndSettle();
        expect(find.text('보유 종목 1'), findsOneWidget);
        expect(find.byKey(const ValueKey('holding-row-AAPL')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'manual prices persist across provider containers and clear correctly',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = ProviderContainer();
      addTearDown(a.dispose);
      await a
          .read(investmentManualPricesProvider.notifier)
          .setPrice('AAPL', 100);
      final b = ProviderContainer();
      addTearDown(b.dispose);
      expect(
        (await b.read(investmentManualPricesProvider.future))['AAPL'],
        100,
      );
      await expectLater(
        b.read(investmentManualPricesProvider.notifier).setPrice('AAPL', -10),
        throwsArgumentError,
      );
      await b
          .read(investmentManualPricesProvider.notifier)
          .setPrice('AAPL', null);
      expect(b.read(investmentManualPricesProvider).requireValue, isEmpty);
    },
  );
}
