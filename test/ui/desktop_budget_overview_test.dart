import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/daos/budget_dao.dart';
import 'package:my_little_budget/features/budget/providers.dart';
import 'package:my_little_budget/ui/desktop/budget/budget_screen.dart';
import 'package:my_little_budget/ui/shared/daily_budget_guidance.dart';

List<BudgetVsActual> sampleBudgetRows() => [
  for (var i = 0; i < 4; i++)
    BudgetVsActual(
      groupId: i + 1,
      groupName: ['취미생활', '식비', '이발, 옷, 병원', '교통비'][i],
      budgetAmount: 100000 * (i + 1),
      baseAmount: 100000 * (i + 1),
      adjustment: 0,
      carryForward: false,
      spentAmount: 30000 * (i + 1),
      usagePercent: 30,
      incomePercentage: null,
      expectedIncome: null,
      accountId: null,
      accountName: null,
      accountColor: null,
      categories: const [],
    ),
];

Widget budgetOverviewHost({
  String? month,
  List<BudgetVsActual>? rows,
  ThemeData? theme,
}) {
  final now = DateTime.now();
  final future = toMonthKey(DateTime(now.year, now.month + 1));
  return ProviderScope(
    overrides: [
      budgetMonthProvider.overrideWith((ref) => month ?? future),
      monthlyExpectedIncomeProvider.overrideWith((ref) async => 2000000),
      budgetRowsProvider.overrideWith(
        (ref) async => rows ?? sampleBudgetRows(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const Scaffold(body: BudgetScreen()),
    ),
  );
}

void main() {
  testWidgets(
    'PC overview aligns three stacked totals with daily guidance and shows the period once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(budgetOverviewHost());
      await tester.pumpAndSettle();
      final summary = find.byKey(const ValueKey('desktop-budget-summary'));
      final guidance = find.byKey(
        const ValueKey('desktop-budget-daily-guidance'),
      );
      final summaryRect = tester.getRect(summary);
      final guidanceRect = tester.getRect(guidance);
      expect(summaryRect.top, guidanceRect.top);
      expect(summaryRect.bottom, guidanceRect.bottom);
      expect(summaryRect.right, lessThan(guidanceRect.left));
      expect(
        tester.getTopLeft(find.text('총 예산')).dy,
        lessThan(tester.getTopLeft(find.text('총 사용액')).dy),
      );
      expect(
        tester.getTopLeft(find.text('총 사용액')).dy,
        lessThan(tester.getTopLeft(find.text('남은 금액')).dy),
      );
      expect(find.textContaining('일 기준'), findsOneWidget);
      final group = find.byKey(const ValueKey('desktop-budget-group-1'));
      expect(tester.getTopLeft(group).dy, greaterThan(summaryRect.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow PC overview stacks the same sections without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(620, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(budgetOverviewHost());
    await tester.pumpAndSettle();
    final summary = tester.getRect(
      find.byKey(const ValueKey('desktop-budget-summary')),
    );
    final guidance = tester.getRect(
      find.byKey(const ValueKey('desktop-budget-daily-guidance')),
    );
    expect(guidance.top, greaterThan(summary.bottom));
    expect(summary.width, guidance.width);
    expect(find.textContaining('일 기준'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'past or empty budgets keep totals without an empty guidance column',
    (tester) async {
      await tester.pumpWidget(budgetOverviewHost(month: '2000-01'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-budget-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-budget-daily-guidance')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(budgetOverviewHost(rows: []));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-budget-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-budget-daily-guidance')),
        findsNothing,
      );
      expect(find.text('이번 달 예산 그룹이 없습니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared mobile guidance preserves its per-group period display by default',
    (tester) async {
      final now = DateTime.now();
      final month = toMonthKey(DateTime(now.year, now.month + 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBudgetGuidance(month: month, rows: sampleBudgetRows()),
          ),
        ),
      );
      expect(find.textContaining('일 기준'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
}
