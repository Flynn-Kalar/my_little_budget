import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/core/theme/theme_colors.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/ui/mobile/stats/widgets/mobile_monthly_trend_card.dart';

void main() {
  final rows = List.generate(
    12,
    (i) => MonthlyTrendRow(
      month: toMonthKey(DateTime(2025, 11 + i)),
      income: 2000000 + i * 10000,
      expense: i == 10 ? 3900590 : 1000000 + i * 23000,
    ),
  );
  Future<void> boot(
    WidgetTester tester,
    List<MonthlyTrendRow> data, {
    double width = 390,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          colors: dark ? darkDefaultTheme : defaultTheme,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MobileMonthlyTrendCard(rows: data),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('same display month keeps each statement period selectable', (
    tester,
  ) async {
    const data = [
      MonthlyTrendRow(
        month: '2026-12',
        periodMonth: '2026-12',
        income: 500,
        expense: 100,
      ),
      MonthlyTrendRow(
        month: '2026-12',
        periodMonth: '2027-01',
        income: 600,
        expense: 200,
      ),
    ];
    await boot(tester, data);
    final graph = tester.widget<LineChart>(find.byType(LineChart));
    final spot = LineBarSpot(
      graph.data.lineBarsData[1],
      1,
      graph.data.lineBarsData[1].spots[1],
    );
    graph.data.lineTouchData.touchCallback!(
      FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [TouchLineBarSpot(spot.bar, spot.barIndex, spot, 0)],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-trend-selected-month')),
        matching: find.text('지출 ${formatKRW(200)}'),
      ),
      findsOneWidget,
    );
  });

  for (final width in [320.0, 390.0, 700.0]) {
    testWidgets(
      'mobile trend includes twelve months, totals and scrollable exact amounts at $width',
      (tester) async {
        await boot(tester, rows, width: width);
        expect(find.text('최근 12개월 추세'), findsOneWidget);
        final totals = find.byKey(const ValueKey('mobile-trend-totals'));
        final income = rows.fold<int>(0, (sum, r) => sum + r.income);
        final expense = rows.fold<int>(0, (sum, r) => sum + r.expense);
        expect(
          find.descendant(of: totals, matching: find.text(formatKRW(income))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: totals, matching: find.text(formatKRW(expense))),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: totals,
            matching: find.text('+${formatKRW(income - expense)}'),
          ),
          findsOneWidget,
        );
        final table = tester.widget<DataTable>(
          find.byKey(const ValueKey('mobile-trend-monthly-table')),
        );
        expect(table.rows, hasLength(12));
        expect(table.columns, hasLength(4));
        expect(find.text('2025.11'), findsOneWidget);
        expect(find.text('2026.10'), findsOneWidget);
        for (final row in rows) {
          expect(find.text(formatKRW(row.expense)), findsWidgets);
        }
        final graph = tester.widget<LineChart>(find.byType(LineChart));
        expect(graph.data.minY, lessThan(0));
        for (final line in graph.data.lineBarsData) {
          expect(line.spots, hasLength(12));
          expect(line.belowBarData.show, isFalse);
        }
        final spot = LineBarSpot(
          graph.data.lineBarsData[1],
          1,
          graph.data.lineBarsData[1].spots[10],
        );
        final tooltip = graph.data.lineTouchData.touchTooltipData
            .getTooltipItems([spot])
            .single!;
        expect(
          tooltip.children!.map((s) => s.toPlainText()).join(),
          contains('지출  ${formatKRW(rows[10].expense)}'),
        );
        graph.data.lineTouchData.touchCallback!(
          FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch)),
          LineTouchResponse(
            touchLocation: Offset.zero,
            touchChartCoordinate: Offset.zero,
            lineBarSpots: [TouchLineBarSpot(spot.bar, spot.barIndex, spot, 0)],
          ),
        );
        await tester.pumpAndSettle();
        final selected = find.byKey(
          const ValueKey('mobile-trend-selected-month'),
        );
        expect(
          find.descendant(of: selected, matching: find.text('2026년 9월')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: selected,
            matching: find.text('지출 ${formatKRW(rows[10].expense)}'),
          ),
          findsOneWidget,
        );
        final scroll = find.byKey(const ValueKey('mobile-trend-chart-scroll'));
        await tester.ensureVisible(scroll);
        await tester.pumpAndSettle();
        await tester.drag(scroll, const Offset(-220, 0));
        await tester.pumpAndSettle();
        if (width < 640) {
          expect(
            tester
                .state<ScrollableState>(
                  find.descendant(
                    of: scroll,
                    matching: find.byType(Scrollable),
                  ),
                )
                .position
                .pixels,
            greaterThan(0),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'large amounts, negative total, dark mode and text scaling retain exact values',
    (tester) async {
      const data = [
        MonthlyTrendRow(
          month: '2026-10',
          income: 1000000,
          expense: 999999999999999,
        ),
      ];
      await boot(tester, data, width: 320, dark: true, scale: 1.5);
      expect(find.text(formatKRW(data.single.net)), findsWidgets);
      final graph = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        (graph.data.maxY - graph.data.minY) /
            graph.data.gridData.horizontalInterval!,
        lessThanOrEqualTo(7),
      );
      expect(tester.takeException(), isNull);
      await boot(tester, const [], width: 320, dark: true);
      expect(find.text('최근 12개월 거래 내역이 없습니다.'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text(formatKRW(0)), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
}
